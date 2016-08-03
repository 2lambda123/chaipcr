//
// Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
// For more information visit http://www.chaibio.com
//
// Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include "wirelessmanager.h"
#include "networkinterfaces.h"
#include "constants.h"
#include "util.h"
#include "logger.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <iostream>
#include <sstream>
#include <stdexcept>
#include <system_error>

#include <unistd.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <sys/eventfd.h>

WirelessManager::WirelessManager()
{
    _connectionEventFd = eventfd(0, EFD_NONBLOCK);

    if (_connectionEventFd == -1)
        throw std::system_error(errno, std::generic_category(), "Wireless manager: unable to create event fd -");

    _connectionThreadState = Idle;
    _connectionStatus = NotConnected;

    _interfaceStatusThreadStatus = Working;
    _interfaceStatusThread = std::thread(&WirelessManager::checkInterfaceStatus, this);
}

WirelessManager::~WirelessManager()
{
    stopCommands();
    close(_connectionEventFd);

    if (_interfaceStatusThread.joinable())
    {
        _interfaceStatusThreadStatus = Stopping;
        _interfaceStatusThread.join();
    }
}

std::string WirelessManager::interfaceName() const
{
    Poco::RWLock::ScopedReadLock lock(_interfaceNameMutex);

    return _interfaceName;
}

void WirelessManager::connect()
{
    if (!interfaceName().empty())
    {
        std::lock_guard<std::recursive_mutex> lock(_commandsMutex);

        stopCommands();

        _connectionStatus = Connecting;
        _connectionThreadState = Working;
        _connectionThread = std::thread(&WirelessManager::_connect, this);
    }
}

void WirelessManager::shutdown()
{
    if (!interfaceName().empty())
    {
        std::lock_guard<std::recursive_mutex> lock(_commandsMutex);

        stopCommands();

        _shutdownThread = std::thread(&WirelessManager::ifdown, this);
    }
}

std::string WirelessManager::getCurrentSsid() const
{
    std::string ssid;
    std::string interface = interfaceName();

    if (!interface.empty())
        Util::watchProcess("iwgetid -r " + interface, [&ssid](const char *buffer, std::size_t size){ ssid.assign(buffer, size); });

    return ssid;
}

std::vector<WirelessManager::ScanResult> WirelessManager::scanResult() const
{
    Poco::RWLock::ScopedReadLock lock(_scanResultMutex);

    return _scanResult;
}

void WirelessManager::setInterfaceName(const std::string &name)
{
    Poco::RWLock::ScopedWriteLock lock(_interfaceNameMutex);
    _interfaceName = name;
}

void WirelessManager::stopCommands()
{
    std::lock_guard<std::recursive_mutex> lock(_commandsMutex);

    if (_connectionThread.joinable())
    {
        _connectionThreadState = Stopping;

        uint64_t i = 1;
        write(_connectionEventFd, &i, sizeof(i));

        _connectionThread.join();

        //Clear event fd
        read(_connectionEventFd, &i, sizeof(i));
    }

    if (_shutdownThread.joinable())
        _shutdownThread.join();
}

void WirelessManager::_connect()
{
    try
    {
        std::string interface = interfaceName();

        if (if_nametoindex(interface.c_str()) == 0)
            throw std::system_error(errno, std::generic_category(), "WirelessManager::_connect - unable to get interface index (" + interface + "):");

        if (_connectionThreadState != Working)
        {
            _connectionThreadState = Idle;
            return;
        }

        ifdown();

        if (_connectionThreadState != Working)
        {
            _connectionThreadState = Idle;
            return;
        }

        NetworkInterfaces::removeLease(interface);

        _connectionStatus = Connecting;

        ifup();

        _connectionThreadState = Idle;
    }
    catch (const std::exception &ex)
    {
        APP_LOGGER << "WirelessManager::_connect - exception occured:" << ex.what() << std::endl;

        _connectionStatus = ConnectionError;
    }
}

void WirelessManager::ifup()
{
    std::string interface = interfaceName();
    LoggerStreams streams;

    std::stringstream stream;
    stream << "ifup " << interface;

    if (!Util::watchProcess(stream.str(), _connectionEventFd, [&streams](const char *buffer, std::size_t size){ streams.stream("WirelessManager::ifup - ifup (stdout)").write(buffer, size); },
                                                             [&streams](const char *buffer, std::size_t size){ streams.stream("WirelessManager::ifup - ifup (stderr)").write(buffer, size); }))
    {
        _connectionStatus = NotConnected;
    }
}

void WirelessManager::ifdown()
{
    NetworkInterfaces::ifdown(interfaceName());

    _connectionStatus = NotConnected;
}

void WirelessManager::checkInterfaceStatus()
{
    while (_interfaceStatusThreadStatus == Working)
    {
        std::string interface = interfaceName();

        if (interface.empty() || if_nametoindex(interface.c_str()) == 0)
        {
            setInterfaceName("");

            for (const std::string &i: NetworkInterfaces::getAllInterfaces())
            {
                if (scan(i))
                {
                    setInterfaceName(i);

                    break;
                }
            }
        }
        else
            scan(interface);

        checkConnection();

        sleep(1);
    }

    _interfaceStatusThreadStatus = Idle;
}

bool WirelessManager::scan(const std::string &interface)
{
    try
    {
        std::stringstream stream;

        Util::watchProcess("iwlist " + interface + " scan", [&stream](const char *buffer, std::size_t size){ stream.write(buffer, size); });

        std::vector<ScanResult> resultList;
        ScanResult result;

        while (stream.good())
        {
            std::string line;
            std::getline(stream, line);

            if (line.find("Cell ") != std::string::npos)
            {
                if (!result.ssid.empty())
                    resultList.emplace_back(result);

                result = ScanResult();
            }
            else if (line.find("ESSID:") != std::string::npos)
            {
                result.ssid = line.substr(line.find("ESSID:") + 7); //Skip ESSID:"
                result.ssid.resize(result.ssid.size() - 1); //Skil " at the end
            }
            else if (line.find("Encryption key:") != std::string::npos)
            {
                if (line.find(":on") != std::string::npos)
                    result.encryption = ScanResult::WepEncryption; //Assume that encryption is wep for now
            }
            else if (line.find("IE: ") != std::string::npos)
            {
                if (line.find("WPA Version 1") != std::string::npos)
                    result.encryption = ScanResult::Wpa1Ecryption;
                else if (line.find("WPA2") != std::string::npos)
                    result.encryption = ScanResult::Wpa2Ecryption;
            }
            else if (line.find("Quality=") != std::string::npos)
            {
                std::string str = line.substr(line.find("Quality=") + 8);
                std::stringstream stream(str);

                stream >> result.quality;

                std::getline(stream, str, '='); //Skip "/100  Signal level="

                stream >> result.siganlLevel;
            }
        }

        if (!result.ssid.empty())
            resultList.emplace_back(result);

        {
            Poco::RWLock::ScopedWriteLock lock(_scanResultMutex);
            _scanResult = std::move(resultList);
        }
    }
    catch (...)
    {
        return false;
    }

    return true;
}

void WirelessManager::checkConnection()
{
    NetworkInterfaces::InterfaceState state = NetworkInterfaces::getInterfaceState(interfaceName());

    if (!state.isEmpty())
    {
        if (state.flags & IFF_UP)
        {
            if (state.addressState)
                _connectionStatus = Connected;
            else if (_connectionThreadState != Working)
                _connectionStatus = AuthenticationError;
        }
        else if (_connectionThreadState != Working)
        {
            if (_connectionStatus == Connecting)
                _connectionStatus = ConnectionError;
            else if (_connectionStatus != ConnectionError)
                _connectionStatus = NotConnected;
        }
    }
}

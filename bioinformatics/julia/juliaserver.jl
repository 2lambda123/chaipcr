using HttpServer, QpcrAnalysis

# Functions like this will be defined as `req2res` in module "QpcrAnalysis"
# function amplification(experiment_id, request_body)
# 	# return true, json response
# 	# or return false, json error response
# 	return true, request_body
# end

http = HttpHandler() do req::Request, res::Response
	if ismatch(r"^/experiments/",req.resource)
		nodes = split(req.resource,'/');
		experiment_id = parse(Int,nodes[3])
		action = nodes[4]
		request_body = bytestring(req.data)
		# func = parse(action)
		code = 0
		# if isdefined(func)
		# 	success, response_body = eval(func)(experiment_id, request_body)
		# 	code = (success)? 200 : 500
		# end
		success, response_body = QpcrAnalysis.Essentials.dispatch(action, request_body)
		code = (success)? 200 : 500
	end

	if code == 0
		code = 404
		response_body = string("{'error': 'method \"", req.resource, "\" not found'}")
	end

	res = Response(response_body)
	res.status = code
	return res
end

server = Server( http )
run( server, 8000 )

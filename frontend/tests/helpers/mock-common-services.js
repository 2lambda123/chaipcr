function mockCommonServices ($provide) {
  $provide.value('User', new UserServiceMock());
  $provide.value('Experiment', ExperimentServiceMock);
  $provide.value('Status', StatusServiceMock);
  $provide.value('NetworkSettingsService', NetworkSettingsServiceMock);
}

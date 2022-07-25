window.addEventListener('job-done', function(e){
  var jobId = e.detail.job_id,
      uploader = document.getElementById('uploader');

  if (uploader.value === 'Dradis::Plugins::CSV') {
    var path = window.location.pathname;
    var project_path = path.split('/').slice(0, -1).join('/');

    var redirectPath  = project_path + '/addons/csv/upload/new?job_id=' + jobId;
    Turbolinks.visit(redirectPath);
  }
});

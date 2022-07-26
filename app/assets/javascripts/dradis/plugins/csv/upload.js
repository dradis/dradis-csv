window.addEventListener('job-done', function(e){
  if ($('body.upload.index').length) {
    var jobId = e.detail.job_id,
        uploader = document.getElementById('uploader');

    if (uploader.value === 'Dradis::Plugins::CSV') {
      var path = window.location.pathname;
      var project_path = path.split('/').slice(0, -1).join('/');
      var attachment = $('#filename').val();

      var redirectPath  = project_path + '/addons/csv/upload/new?attachment=' + attachment;
      Turbolinks.visit(redirectPath);
    }
  }
});

document.addEventListener('turbolinks:load', function() {
  if ($('body.upload.new').length) {
    $('[data-behavior=type-select]').on('change', function() {
      var $nodeSelect = $('select option[value="node"]:selected').parent();

      $('[data-behavior=type-select]').each(function(i, select) {
        var $tr = $(select).closest('tr');

        $tr.find('[data-behavior=na-field-label]').addClass('d-none');
        $tr.find('[data-behavior=default-field-label]').removeClass('d-none');

        if ($nodeSelect.length && !$nodeSelect.is($(select))) {
          $(select).find('option[value="node"]').attr('disabled', 'disabled');
        } else {
          $(select).find('option[value="node"]').removeAttr('disabled');
        }
      });

      $nodeSelect.closest('tr').find('[data-behavior=na-field-label]').removeClass('d-none');
      $nodeSelect.closest('tr').find('[data-behavior=default-field-label]').addClass('d-none');
    });
  }
});

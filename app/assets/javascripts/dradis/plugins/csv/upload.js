window.addEventListener('job-done', function(e){
  if ($('body.upload.index').length) {
    var jobId = e.detail.job_id,
        uploader = document.getElementById('uploader');

    if (uploader.value === 'Dradis::Plugins::CSV') {
      var path = window.location.pathname;
      var project_path = path.split('/').slice(0, -1).join('/');

      var redirectPath  = project_path + '/addons/csv/upload/new?job_id=' + jobId;
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

    $('[data-behavior~=mapping-form]').submit(function() {
      var valid = validateIdentifierSelected() && validateNodeSelected();

      if (!valid) {
        $(this).find('input[type="submit"]').attr('disabled', false).val('Import CSV');

        $('[data-behavior~=view-content]').animate({
          scrollTop: $('[data-behavior~=validation-messages]').scrollTop()
        });
      }

      return valid;
    });

    function validateNodeSelected() {
      var $validationMessage = $('[data-behavior~=node-type-validation-message]');
      $validationMessage.addClass('d-none');

      var selectedEvidenceCount = $('select option[value="evidence"]:selected').length;
      var selectedNodeCount = $('select option[value="node"]:selected').length;

      var valid =  selectedEvidenceCount == 0 ||
                   (selectedEvidenceCount > 0 && selectedNodeCount > 0);

      if (!valid) {
        $validationMessage.removeClass('d-none');
      }

      return valid;
    }

    function validateIdentifierSelected() {
      var $validationMessage = $('[data-behavior~=issue-id-validation-message]');
      $validationMessage.addClass('d-none');

      var selectedIdentifierCount = $('select option[value="identifier"]:selected').length;

      var valid = selectedIdentifierCount == 1;

      if (!valid) {
        $validationMessage.removeClass('d-none');
      }

      return valid;
    }
  }
});

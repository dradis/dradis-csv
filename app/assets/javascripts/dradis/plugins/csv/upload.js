window.addEventListener('job-done', function(e){
  if ($('body.upload.index').length) {
    var jobId = e.detail.job_id,
        uploader = document.getElementById('uploader');

    if (uploader.value === 'Dradis::Plugins::CSV') {
      var path = window.location.pathname;
      var project_path = path.split('/').slice(0, -1).join('/');

      var redirectPath  = project_path + '/csv/upload/new?job_id=' + jobId;
      Turbolinks.visit(redirectPath);
    }
  }
});

document.addEventListener('turbolinks:load', function() {
  if ($('body.upload.new').length) {
    $('[data-behavior=type-select]').on('change', function(e) {
      var $nodeSelect = $('select option[value="node"]:selected').parent();

      // Disable Node Label option and update fields column labels
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

      setDradisFieldSelect($(e.target));
    });

    $('[data-behavior~=mapping-form]').on('ajax:before', function() {
      $('#console').empty();
      $('#result').show();
    });

    $('[data-behavior~=mapping-form]').on('ajax:complete', function() {
      ConsoleUpdater.parsing = true;
      setTimeout(ConsoleUpdater.updateConsole, 1000);
    });

    $('[data-behavior~=mapping-form]').submit(function() {
      var valid = validateUniqueId() && validateNodeSelected();

      if (!valid) {
        $(this).find('input[type="submit"]').attr('disabled', false).val('Import CSV');

        $('[data-behavior~=view-content]').animate({
          scrollTop: $('[data-behavior~=mapping-validation-messages]').scrollTop()
        });
      }

      return valid;
    });

    function validateUniqueId() {
      $('[data-behavior~=unique-id-validation-message]').addClass('d-none');

      var valid = $('[data-behavior~=identifier]').is(':checked');

      if (!valid) {
        $('[data-behavior~=unique-id-validation-message]').removeClass('d-none');
      }

      return valid;
    }

    function validateNodeSelected() {
      $('[data-behavior~=node-type-validation-message]').addClass('d-none');

      var selectedEvidenceCount = $('select option[value="evidence"]:selected').length;
      var selectedNodeCount = $('select option[value="node"]:selected').length;

      var valid =  selectedEvidenceCount == 0 ||
                   (selectedEvidenceCount > 0 && selectedNodeCount > 0);

      if (!valid) {
        $('[data-behavior~=node-type-validation-message]').removeClass('d-none');
      }

      return valid;
    }
  }

  var setDradisFieldSelect = function($select) {
    var rtpFields = $('[data-behavior=dradis-datatable]').data('rtp-fields');
    if (rtpFields) {
      var fields = rtpFields[$select.val()] || [],
          $fieldSelect = $select.closest('tr').find('[data-behavior=field-select]');

      if (fields.length > 0) {
        $fieldSelect.empty();
        fields.forEach(function(value) {
          $fieldSelect.append($('<option></option>').attr('value', value).text(value));
        });
      }
      else {
        $fieldSelect.html($('<option disabled="disabled" selected></option>').attr('value', '').text('N/A'));
      }
    }
  }
});

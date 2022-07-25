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

      // Disable Node Label option
      if ($nodeSelect.length) {
        $('[data-behavior=type-select]').not($nodeSelect).find('option[value="node"]').attr('disabled', 'disabled');
      } else {
        $('[data-behavior=type-select]').find('option[value="node"]').removeAttr('disabled');
      }

      $(this).parents('tr').toggleClass('issue-type', $(this).val() == 'issue');

      // Update fields column labels
      var nodeSelected = $(this).val() == 'node',
          skipSelected = $(this).val() == 'skip',
          $fieldLabel = $(this).closest('tr').find('[data-behavior=field-label]');

      if (skipSelected) {
        $fieldLabel.text('N/A');
      } else if (nodeSelected) {
        $fieldLabel.text('Label');
      } else {
        var header = $fieldLabel.data('header');
        $fieldLabel.text(header);
      }

      _setDradisFieldSelect($(this));
    });

    $('[data-behavior=identifier]').on('mousedown', function(e){
      var $previousRow = $('[data-behavior=identifier]:checked').closest('tr'),
          $currentRow = $(this).closest('tr');

      _resetRow($previousRow);
      _disableIdentifierRow($currentRow);
    });

    $('[data-behavior~=mapping-form]').submit(function() {
      var valid = _validateIdentifierSelected() && _validateNodeSelected();

      if (!valid) {
        $(this).find('input[type="submit"]').attr('disabled', false).val('Import CSV');

        $('[data-behavior~=view-content]').animate({
          scrollTop: $('[data-behavior~=validation-messages]').scrollTop()
        });
      }

      return valid;
    });

    // Private methods

    function _setDradisFieldSelect($select) {
      var rtpFields = $('[data-behavior=dradis-datatable]').data('rtp-fields');
      if (rtpFields) {
        var fields = rtpFields[$select.val()],
            $fieldSelect = $select.closest('tr').find('[data-behavior=field-select]');

        if ($select.val() in rtpFields){
          if (fields.length > 0) {
            $fieldSelect.empty();
            fields.forEach(function(value) {
              $fieldSelect
                .removeAttr('disabled')
                .append(
                  $('<option></option>').attr('value', value).text(value)
                );
            });
          }
          else {
            var header = $fieldSelect.data('header');
            $fieldSelect
              .html(
                $('<option disabled="disabled" selected></option>').attr('value', header).text(header)
              );
          }
        } else if ($select.val()== 'node') {
          $fieldSelect
            .attr('disabled', 'disabled')
            .html(
              $('<option></option>').attr('value', '').text('Label')
            );
        } else {
          $fieldSelect
            .attr('disabled', 'disabled')
            .html(
              $('<option></option>').attr('value', '').text('N/A')
            );
        }
      }
    }

    function _disableIdentifierRow($row) {
      var $fieldSelect = $row.find('[data-behavior=field-select]'),
          $typeSelect = $row.find('[data-behavior=type-select]');

      $typeSelect.attr('disabled', 'disabled');
      $typeSelect.val('issue').change();

      $fieldSelect.attr('disabled', 'disabled');
      // With RTP
      $fieldSelect.html($('<option selected></option>').attr('value', 'plugin_id').text('plugin_id'));
      // With no RTP
      $row.find('[data-behavior=field-label]').text('plugin_id');
    }

    function _resetRow($row) {
      var $fieldSelect = $row.find('[data-behavior=field-select]'),
          $typeSelect = $row.find('[data-behavior=type-select]'),
          $fieldLabel = $row.find('[data-behavior=field-label]');

      $fieldSelect.removeAttr('disabled');
      $typeSelect.removeAttr('disabled');

      // With RTP
      _setDradisFieldSelect($typeSelect);
      // With no RTP
      $fieldLabel.text($fieldLabel.data('header'));
    }

    function _validateNodeSelected() {
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

    function _validateIdentifierSelected() {
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

window.addEventListener('job-done', function(){
  if ($('body.upload.index').length) {
    var uploader = document.getElementById('uploader');

    if (uploader.value === 'Dradis::Plugins::CSV') {
      var path = window.location.pathname;
      var project_path = path.split('/').slice(0, -1).join('/');
      var attachment = $('#attachment').val();

      var redirectPath  = project_path + '/addons/csv/upload/new?attachment=' + attachment;
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
      var $row = $select.closest('tr');

      $row.find('.field-select').attr('disabled', 'disabled').addClass('d-none');
      if ($select.val() == 'issue') {
        $row.find('[data-behavior=issue-field-select]').removeAttr('disabled', 'disabled').removeClass('d-none');
      }
      else if ($select.val() == 'evidence') {
        $row.find('[data-behavior=evidence-field-select]').removeAttr('disabled').removeClass('d-none');
      }
      else {
        $row.find('[data-behavior=empty-field-select]').removeAttr('disabled').removeClass('d-none');
      }
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

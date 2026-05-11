window.addEventListener('job-done', function () {
  if ($('body.upload.index').length) {
    var uploader = document.getElementById('uploader');

    if (uploader.value === 'Dradis::Plugins::CSV') {
      var state = document.getElementById('state').value;
      var path = window.location.pathname;
      var project_path = path.split('/').slice(0, -1).join('/');
      var attachment = $('#attachment').val();

      var params = new URLSearchParams({ attachment: attachment, state: state });
      var redirectPath =
        project_path + '/addons/csv/upload/new?' + params.toString();
      Turbo.visit(redirectPath);
    }
  }
});

document.addEventListener('turbo:load', function() {
  if ($('body.dradis-plugins-csv-upload.new').length) {
    $('[data-behavior=type-select]').on('change', function () {
      var $nodeSelect = $('select option[value="node"]:selected').parent();

      // Disable Node Label option
      if ($nodeSelect.length) {
        $('[data-behavior=type-select]')
          .not($nodeSelect)
          .find('option[value="node"]')
          .attr('disabled', 'disabled');
      } else {
        $('[data-behavior=type-select]')
          .find('option[value="node"]')
          .removeAttr('disabled');
      }

      $(this)
        .parents('tr')
        .toggleClass('issue-type', $(this).val() == 'issue');

      // Update fields column labels
      var $fieldLabel = $(this)
        .closest('tr')
        .find('[data-behavior=field-label]');

      switch ($(this).val()) {
        case 'identifier':
          $fieldLabel.text('plugin_id');
          break;
        case 'node':
          $fieldLabel.text('Label');
          break;
        case 'skip':
          $fieldLabel.text('N/A');
          break;
        default:
          var header = $fieldLabel.data('header');
          $fieldLabel.text(header);
      }

      _setDradisFieldSelect($(this));
    });

    $('[data-behavior~=mapping-form]').submit(function () {
      var valid = _validateIdentifierSelected() && _validateNodeSelected();

      if (!valid) {
        $(this)
          .find('input[type="submit"]')
          .attr('disabled', false)
          .val('Import CSV');

        $('[data-behavior~=view-content]').animate({
          scrollTop: $('[data-behavior~=validation-messages]').scrollTop()
        });
      }

      return valid;
    });

    $(document).on('change', '[data-behavior~=dradis-field-select]', function () {
      const $input = $(this).closest('td').find('[data-behavior~=custom-field-input]');
      $input.toggleClass('d-none', $(this).val() !== 'Custom Field');
      if ($(this).val() !== 'Custom Field') $input.val('');
    });

    $('[data-behavior~=save-mapping-checkbox]').on('change', function () {
      $('[data-behavior~=save-mapping-name]').toggleClass('d-none', !$(this).is(':checked'));
    });

    $('[data-behavior~=saved-mapping-select]').on('change', function () {
      const selectedOption = $(this).find('option:selected');
      const fields = selectedOption.data('fields') || [];

      // Reset every row to 'skip' so unmatched columns are excluded and
      // re-applying a different mapping always starts from a clean state.
      $('table tbody tr').each(function () {
        const $row = $(this);
        $row.find('[data-behavior~=type-select]').val('skip');
        $row.removeClass('issue-type');
        $row.find('[data-behavior~=custom-field-input]').addClass('d-none').val('');
        $row.find('[data-behavior~=dradis-field-select]').attr('disabled', 'disabled').addClass('d-none');
        $row.find('[data-behavior~=empty-field-select]').attr('disabled', 'disabled').removeClass('d-none');
      });
      $('[data-behavior~=type-select]').find('option[value="node"]').removeAttr('disabled');

      const appliedRows = new Set();

      fields.forEach(function (field) {
        const sourceField = field.source_field;
        const destField = field.destination_field;

        let type, fieldName;
        if (destField === 'Node Label') {
          type = 'node';
        } else if (destField === 'Issue ID') {
          type = 'identifier';
        } else if (destField.startsWith('Evidence: ')) {
          type = 'evidence';
          fieldName = destField.slice('Evidence: '.length);
        } else if (destField.startsWith('Issue: ')) {
          type = 'issue';
          fieldName = destField.slice('Issue: '.length);
        } else {
          type = 'issue';
          fieldName = destField;
        }

        $('table tbody tr').each(function (rowIndex) {
          if (appliedRows.has(rowIndex)) return true;
          const header = $(this).find('td:first').text().trim();
          if (header === sourceField) {
            appliedRows.add(rowIndex);
            const $row = $(this);

            const typeSelectEl = $row.find('[data-behavior~=type-select]')[0];
            if (typeSelectEl) typeSelectEl.value = type;
            $row.toggleClass('issue-type', type === 'issue');

            $row.find('[data-behavior~=custom-field-input]').addClass('d-none').val('');
            $row.find('[data-behavior~=dradis-field-select]').attr('disabled', 'disabled').addClass('d-none');

            if (type === 'issue') {
              $row.find('[data-behavior~=issue-field-select]').removeAttr('disabled').removeClass('d-none');
            } else if (type === 'evidence') {
              $row.find('[data-behavior~=evidence-field-select]').removeAttr('disabled').removeClass('d-none');
            } else {
              $row.find('[data-behavior~=empty-field-select]').attr('disabled', 'disabled').removeClass('d-none');
            }

            if (type === 'node') {
              $('[data-behavior~=type-select]').not($row.find('[data-behavior~=type-select]'))
                .find('option[value="node"]').attr('disabled', 'disabled');
            }

            setTimeout(function () {
              if (type === 'issue' || type === 'evidence') {
                const behavior = type === 'issue' ? 'issue-field-select' : 'evidence-field-select';
                const $fieldSelect = $row.find(`[data-behavior~=${behavior}]`);
                if (fieldName === 'Custom Field') {
                  $fieldSelect.val('Custom Field').trigger('change');
                } else {
                  $fieldSelect.val(fieldName);
                  if (!$fieldSelect.val()) {
                    $fieldSelect.val('Custom Field').trigger('change');
                    $row.find('[data-behavior~=custom-field-input]').val(fieldName);
                  }
                }
              }
            }, 0);
            return false;
          }
        });
      });
    });

    // Private methods

    function _setDradisFieldSelect($select) {
      var $row = $select.closest('tr');

      $row.find('[data-behavior~=custom-field-input]').addClass('d-none').val('');

      $row
        .find('[data-behavior~=dradis-field-select]')
        .attr('disabled', 'disabled')
        .addClass('d-none');

      if ($select.val() == 'issue') {
        $row
          .find('[data-behavior~=issue-field-select]')
          .removeAttr('disabled')
          .removeClass('d-none');
      } else if ($select.val() == 'evidence') {
        $row
          .find('[data-behavior~=evidence-field-select]')
          .removeAttr('disabled')
          .removeClass('d-none');
      } else {
        $row
          .find('[data-behavior~=empty-field-select]')
          .attr('disabled', 'disabled')
          .removeClass('d-none');
      }
    }

    function _validateNodeSelected() {
      var $validationMessage = $(
        '[data-behavior~=node-type-validation-message]'
      );
      $validationMessage.addClass('d-none');

      var selectedEvidenceCount = $(
        'select option[value="evidence"]:selected'
      ).length;
      var selectedNodeCount = $('select option[value="node"]:selected').length;

      var valid =
        selectedEvidenceCount == 0 ||
        (selectedEvidenceCount > 0 && selectedNodeCount > 0);

      if (!valid) {
        $validationMessage.removeClass('d-none');
      }

      return valid;
    }

    function _validateIdentifierSelected() {
      var $validationMessage = $(
        '[data-behavior~=issue-id-validation-message]'
      );
      $validationMessage.addClass('d-none');

      var selectedIdentifierCount = $(
        'select option[value="identifier"]:selected'
      ).length;

      var valid = selectedIdentifierCount == 1;

      if (!valid) {
        $validationMessage.removeClass('d-none');
      }

      return valid;
    }
  }
});

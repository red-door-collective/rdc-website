from eviction_tracker import detainer_warrants
from datetime import datetime
import time
from flask import current_app
import shutil
import os


def export_zip(app, req_id):
    with app.app_context():
        export_dir = req_id
        export_path = f"{current_app.config['DATA_DIR']}/davidson-co/eviction-data/export/{export_dir}"
        if not os.path.exists(export_path):
            os.makedirs(export_path)

        csv_filename = 'detainer-warrants.csv'
        detainer_warrants.exports.warrants_to_csv(export_path + '/' + csv_filename,
                                                  omit_defendant_info=True)

        # detainer_warrants.exports.to_judgment_sheet(
        # workbook_name, omit_defendant_info, service_account_key)

        shutil.make_archive(export_path, 'zip', export_path)

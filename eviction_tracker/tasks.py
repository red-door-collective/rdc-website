from eviction_tracker import detainer_warrants
from datetime import datetime
import time
from flask import current_app
import shutil
import os
from .email import export_notification
from flask_mail import Attachment
from .time_util import millis_timestamp, file_friendly_timestamp


class Task:
    def __init__(self, id, requester):
        self.id = id
        self.requester = requester
        self.started_at = datetime.now()

    def to_json(self):
        return {'id': self.id, 'started_at': millis_timestamp(self.started_at)}


def export_zip(app, task):
    with app.app_context():
        export_dir = task.id
        export_path = f"{current_app.config['DATA_DIR']}/davidson-co/eviction-data/export/{export_dir}"
        if not os.path.exists(export_path):
            os.makedirs(export_path)

        csv_filename = 'detainer-warrants.csv'
        detainer_warrants.exports.warrants_to_csv(export_path + '/' + csv_filename,
                                                  omit_defendant_info=True)

        judgment_csv_filename = 'judgments.csv'
        detainer_warrants.exports.judgments_to_csv(
            export_path + '/' + judgment_csv_filename,
            omit_defendant_info=True
        )

        shutil.make_archive(export_path, 'zip', export_path)

        attachments = []
        with open(export_path + '.zip', 'rb') as fp:
            attachments.append(Attachment(
                filename=f'eviction-data-davidson-co-{file_friendly_timestamp(task.started_at)}.zip',
                content_type='application/zip',
                data=fp.read()
            ))

        export_notification(task, attachments)

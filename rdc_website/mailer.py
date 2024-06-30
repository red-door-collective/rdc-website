# from flask import render_template, current_app
from flask_mail import Message
from .extensions import mail


def send(subject, sender, recipients, text_body, html_body, attachments=None):
    msg = Message(subject, sender=sender, recipients=recipients)
    msg.body = text_body
    msg.html = html_body
    if attachments:
        for attachment in attachments:
            msg.attach(
                filename=attachment.filename,
                content_type=attachment.content_type,
                data=attachment.data,
            )
    mail.send(msg)


def export_notification(task, attachments, start_date, end_date):
    send(
        f"{task.requester['first_name']}'s requested data on evictions from Red Door Collective",
        current_app.config["MAIL_ADMIN"],
        [task.requester["email"]],
        render_template(
            "export_notification.txt",
            task=task,
            start_date=start_date,
            end_date=end_date,
        ),
        render_template(
            "export_notification.html",
            task=task,
            start_date=start_date,
            end_date=end_date,
        ),
        attachments=attachments,
    )

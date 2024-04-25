from marshmallow import Schema, fields
from rdc_website.detainer_warrants.serializers import (
    DefendantSchema,
    DetainerWarrantSchema,
)


class PhoneBankEventSchema(Schema):
    tenants = fields.Nested(DefendantSchema, many=True)

    class Meta:
        fields = ("id", "name", "type", "tenants")


phone_bank_event_schema = PhoneBankEventSchema()
phone_bank_events_schema = PhoneBankEventSchema(many=True)


class EventSchema(Schema):
    tenants = fields.Nested(DefendantSchema, many=True)
    warrants = fields.Nested(DetainerWarrantSchema, many=True)

    class Meta:
        fields = ("id", "name", "type", "tenants", "warrants")


event_schema = EventSchema()
events_schema = EventSchema(many=True)


class CampaignSchema(Schema):
    events = fields.Nested(EventSchema(only=("id", "name"), many=True))

    class Meta:
        fields = ("id", "name", "events")


campaign_schema = CampaignSchema()
campaigns_schema = CampaignSchema(many=True)

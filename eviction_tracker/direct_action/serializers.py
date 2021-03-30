from marshmallow import Schema, fields
from eviction_tracker.detainer_warrants.serializers import DefendantSchema


class PhoneBankEventSchema(Schema):
    tenants = fields.Nested(DefendantSchema, many=True)

    class Meta:
        fields = ("id", "name", "tenants")


phone_bank_event_schema = PhoneBankEventSchema()
phone_bank_events_schema = PhoneBankEventSchema(many=True)


class CampaignSchema(Schema):
    events = fields.Nested(PhoneBankEventSchema, many=True)

    class Meta:
        fields = ("id", "name", "events")


campaign_schema = CampaignSchema()
campaigns_schema = CampaignSchema(many=True)

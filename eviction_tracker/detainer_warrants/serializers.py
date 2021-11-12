from marshmallow import Schema, fields
from ..admin import serializers


class DistrictSchema(Schema):
    class Meta:
        fields = ("id", "name")


district_schema = DistrictSchema()
districts_schema = DistrictSchema(many=True)


class AttorneySchema(Schema):
    class Meta:
        fields = ("id", "name", "aliases", "district_id")


attorney_schema = AttorneySchema()
attorneys_schema = AttorneySchema(many=True)


class PhoneNumberVerificationSchema(Schema):
    class Meta:
        fields = ("caller_name", "caller_type", "phone_type",  "error_code", "carrier",
                  "country_code", "national_format", "phone_number")


phone_number_verification_schema = PhoneNumberVerificationSchema()
phone_number_verifications_schema = PhoneNumberVerificationSchema(many=True)


class DefendantSchema(Schema):
    verified_phone = fields.Nested(
        PhoneNumberVerificationSchema)

    class Meta:
        fields = ("id", "name", "first_name", "middle_name", "last_name", "suffix", "aliases",
                  "address", "verified_phone", "potential_phones", "district_id")


defendant_schema = DefendantSchema()
defendants_schema = DefendantSchema(many=True)


class CourtroomSchema(Schema):
    class Meta:
        fields = ("id", "name", "district_id")


courtroom_schema = CourtroomSchema()
courtrooms_schema = CourtroomSchema(many=True)


class PlaintiffSchema(Schema):
    class Meta:
        fields = ("id", "name", "aliases", "district_id")


plaintiff_schema = PlaintiffSchema()
plaintiffs_schema = PlaintiffSchema(many=True)


class JudgeSchema(Schema):
    class Meta:
        fields = ("id", "name", "aliases", "district_id")


judge_schema = JudgeSchema()
judges_schema = JudgeSchema(many=True)


class JudgementSchema(Schema):
    id = fields.Int(allow_none=True)
    court_date = fields.Int(allow_none=True)
    awards_possession = fields.Bool(allow_none=True)
    awards_fees = fields.Float(allow_none=True)
    entered_by = fields.String(allow_none=True)
    interest = fields.Bool(allow_none=True)
    interest_rate = fields.Float(allow_none=True)
    interest_follows_site = fields.Bool(allow_none=True)
    dismissal_basis = fields.String(allow_none=True)
    with_prejudice = fields.Bool(allow_none=True)
    notes = fields.String(allow_none=True)

    judge = fields.Nested(JudgeSchema, allow_none=True)
    plaintiff = fields.Nested(PlaintiffSchema, allow_none=True)
    plaintiff_attorney = fields.Nested(AttorneySchema, allow_none=True)
    defendant_attorney = fields.Nested(AttorneySchema, allow_none=True)
    courtroom = fields.Nested(CourtroomSchema, allow_none=True)
    detainer_warrant = fields.Nested(
        lambda: DetainerWarrantSchema(only=["docket_id"]))

    class Meta:
        fields = ("id", "court_date", "in_favor_of", "awards_possession",
                  "awards_fees", "entered_by", "interest", "interest_rate",
                  "interest_follows_site", "dismissal_basis", "with_prejudice", "notes",
                  "judge", "plaintiff", "plaintiff_attorney", "defendant_attorney", "courtroom",
                  "detainer_warrant"
                  )


judgement_schema = JudgementSchema()
judgements_schema = JudgementSchema(many=True)


class PleadingDocumentSchema(Schema):
    class Meta:
        fields = ("url", "text", "kind", "docket_id",
                  "created_at", "updated_at")


pleading_document_schema = PleadingDocumentSchema()
pleading_documents_schema = PleadingDocumentSchema(many=True)


class DetainerWarrantSchema(Schema):
    plaintiff = fields.Nested(PlaintiffSchema, allow_none=True)
    plaintiff_attorney = fields.Nested(AttorneySchema, allow_none=True)
    defendants = fields.Nested(DefendantSchema, many=True)
    judgements = fields.Nested(JudgementSchema, many=True)
    pleadings = fields.Nested(PleadingDocumentSchema, many=True)
    last_edited_by = fields.Nested(serializers.UserSchema)

    file_date = fields.Int(allow_none=True)
    status = fields.String(allow_none=True)
    amount_claimed = fields.Float(allow_none=True)
    court_date = fields.Int(allow_none=True)
    is_cares = fields.Bool(allow_none=True)
    is_legacy = fields.Bool(allow_none=True)
    nonpayment = fields.Bool(allow_none=True)
    notes = fields.String(allow_none=True)

    class Meta:
        fields = ("docket_id", "order_number", "file_date", "status", "court_date", "amount_claimed", "amount_claimed_category",
                  "judgements", "last_edited_by", "plaintiff", "plaintiff_attorney", "defendants",
                  "zip_code", "is_legacy", "is_cares", "nonpayment", "notes", "pleadings", "created_at", "updated_at")


detainer_warrant_schema = DetainerWarrantSchema()
detainer_warrants_schema = DetainerWarrantSchema(many=True)

from marshmallow import Schema, fields
from ..admin import serializers


class AttorneySchema(Schema):
    class Meta:
        fields = ("id", "name", "aliases")


attorney_schema = AttorneySchema()
attorneys_schema = AttorneySchema(many=True)


class PhoneNumberVerificationSchema(Schema):
    class Meta:
        fields = (
            "caller_name",
            "caller_type",
            "phone_type",
            "error_code",
            "carrier",
            "country_code",
            "national_format",
            "phone_number",
        )


phone_number_verification_schema = PhoneNumberVerificationSchema()
phone_number_verifications_schema = PhoneNumberVerificationSchema(many=True)


class DefendantSchema(Schema):
    verified_phone = fields.Nested(PhoneNumberVerificationSchema)

    class Meta:
        fields = (
            "id",
            "name",
            "first_name",
            "middle_name",
            "last_name",
            "suffix",
            "aliases",
            "verified_phone",
            "potential_phones",
        )


defendant_schema = DefendantSchema()
defendants_schema = DefendantSchema(many=True)


class CourtroomSchema(Schema):
    class Meta:
        fields = ("id", "name")


courtroom_schema = CourtroomSchema()
courtrooms_schema = CourtroomSchema(many=True)


class PlaintiffSchema(Schema):
    class Meta:
        fields = ("id", "name", "aliases")


plaintiff_schema = PlaintiffSchema()
plaintiffs_schema = PlaintiffSchema(many=True)


class JudgeSchema(Schema):
    class Meta:
        fields = ("id", "name", "aliases")


judge_schema = JudgeSchema()
judges_schema = JudgeSchema(many=True)


class JudgmentSchema(Schema):
    id = fields.Int(allow_none=True)
    file_date = fields.Int(allow_none=True)
    awards_possession = fields.Bool(allow_none=True)
    awards_fees = fields.Float(allow_none=True)
    entered_by = fields.String(allow_none=True)
    interest = fields.Bool(allow_none=True)
    interest_rate = fields.Float(allow_none=True)
    interest_follows_site = fields.Bool(allow_none=True)
    dismissal_basis = fields.String(allow_none=True)
    with_prejudice = fields.Bool(allow_none=True)
    notes = fields.String(allow_none=True)

    hearing = fields.Nested(lambda: HearingSchema, allow_none=True)
    judge = fields.Nested(JudgeSchema, allow_none=True)
    plaintiff = fields.Nested(PlaintiffSchema, allow_none=True)
    plaintiff_attorney = fields.Nested(AttorneySchema, allow_none=True)
    defendant_attorney = fields.Nested(AttorneySchema, allow_none=True)
    document = fields.Nested(lambda: PleadingDocumentSchema, allow_none=True)

    class Meta:
        fields = (
            "id",
            "hearing",
            "detainer_warrant_id",
            "file_date",
            "in_favor_of",
            "awards_possession",
            "awards_fees",
            "entered_by",
            "interest",
            "interest_rate",
            "interest_follows_site",
            "dismissal_basis",
            "with_prejudice",
            "notes",
            "judge",
            "plaintiff",
            "plaintiff_attorney",
            "defendant_attorney",
            "document",
        )


judgment_schema = JudgmentSchema()
judgments_schema = JudgmentSchema(many=True)


class HearingSchema(Schema):
    id = fields.Int(allow_none=True)
    court_date = fields.Int(allow_none=True)
    docket_id = fields.String(allow_none=True)
    continuance_on = fields.Int(allow_none=True)

    judgment = fields.Nested(JudgmentSchema(only=("id",)), allow_none=True)
    judge = fields.Nested(JudgeSchema, allow_none=True)
    plaintiff = fields.Nested(PlaintiffSchema, allow_none=True)
    plaintiff_attorney = fields.Nested(AttorneySchema, allow_none=True)
    defendant_attorney = fields.Nested(AttorneySchema, allow_none=True)
    courtroom = fields.Nested(CourtroomSchema, allow_none=True)

    class Meta:
        fields = (
            "id",
            "court_date",
            "docket_id",
            "continuance_on",
            "address",
            "courtroom",
            "judgment",
            "plaintiff",
            "plaintiff_attorney",
            "defendant_attorney",
        )


hearing_schema = HearingSchema()
hearings_schema = HearingSchema(many=True)


class PleadingDocumentSchema(Schema):
    class Meta:
        fields = ("image_path", "text", "kind", "docket_id", "created_at", "updated_at")


pleading_document_schema = PleadingDocumentSchema()
pleading_documents_schema = PleadingDocumentSchema(many=True)


class DetainerWarrantSchema(Schema):
    plaintiff = fields.Nested(PlaintiffSchema, allow_none=True)
    plaintiff_attorney = fields.Nested(AttorneySchema, allow_none=True)
    hearings = fields.Nested(HearingSchema, many=True)
    last_edited_by = fields.Nested(serializers.UserSchema)
    document = fields.Nested(lambda: PleadingDocumentSchema, allow_none=True)

    docket_id = fields.String()
    address = fields.String(allow_none=True)
    file_date = fields.Int(allow_none=True)
    status = fields.String(allow_none=True)
    amount_claimed = fields.Float(allow_none=True)
    claims_possession = fields.Bool(allow_none=True)
    court_date = fields.Int(allow_none=True)
    is_cares = fields.Bool(allow_none=True)
    is_legacy = fields.Bool(allow_none=True)
    nonpayment = fields.Bool(allow_none=True)
    notes = fields.String(allow_none=True)
    audit_status = fields.String(allow_none=True)
    created_at = fields.Int()
    updated_at = fields.Int()

    class Meta:
        fields = (
            "docket_id",
            "address",
            "order_number",
            "file_date",
            "status",
            "court_date",
            "amount_claimed",
            "claims_possession",
            "hearings",
            "last_edited_by",
            "plaintiff",
            "plaintiff_attorney",
            "is_legacy",
            "is_cares",
            "nonpayment",
            "notes",
            "audit_status",
            "created_at",
            "updated_at",
            "document",
        )


detainer_warrant_schema = DetainerWarrantSchema()
detainer_warrants_schema = DetainerWarrantSchema(many=True)

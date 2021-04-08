from marshmallow import Schema, fields


class DistrictSchema(Schema):
    class Meta:
        fields = ("id", "name")


district_schema = DistrictSchema()
districts_schema = DistrictSchema(many=True)


class AttorneySchema(Schema):
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "district")


attorney_schema = AttorneySchema()
attorneys_schema = AttorneySchema(many=True)


class PhoneNumberVerificationSchema(Schema):
    class Meta:
        fields = ("caller_name", "caller_type", "phone_type",  "error_code", "carrier",
                  "country_code", "national_format", "phone_number")


phone_number_verification_schema = PhoneNumberVerificationSchema()
phone_number_verifications_schema = PhoneNumberVerificationSchema(many=True)


class DefendantSchema(Schema):
    district = fields.Nested(DistrictSchema)
    verified_phone = fields.Nested(
        PhoneNumberVerificationSchema)

    class Meta:
        fields = ("id", "name", "first_name", "middle_name", "last_name", "suffix", "district", "address",
                  "verified_phone", "potential_phones")


defendant_schema = DefendantSchema()
defendants_schema = DefendantSchema(many=True)


class CourtroomSchema(Schema):
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "district")


courtroom_schema = CourtroomSchema()
courtrooms_schema = CourtroomSchema(many=True)


class PlaintiffSchema(Schema):
    attorney = fields.Nested(AttorneySchema)
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "attorney", "district")


plaintiff_schema = PlaintiffSchema()
plaintiffs_schema = PlaintiffSchema(many=True)


class JudgeSchema(Schema):
    district = fields.Nested(DistrictSchema)

    class Meta:
        fields = ("id", "name", "district")


judge_schema = JudgeSchema()
judges_schema = JudgeSchema(many=True)


class DetainerWarrantSchema(Schema):
    plaintiff = fields.Nested(PlaintiffSchema)
    courtroom = fields.Nested(CourtroomSchema)
    presiding_judge = fields.Nested(JudgeSchema)
    defendants = fields.Nested(DefendantSchema, many=True)

    amount_claimed = fields.Float()

    class Meta:
        fields = ("docket_id", "file_date", "status", "court_date", "amount_claimed", "amount_claimed_category",
                  "judgement", "judgement_notes", "plaintiff", "courtroom", "presiding_judge", "defendants",
                  "zip_code", "is_legacy", "is_cares", "nonpayment", "notes")


class DetainerWarrantEditSchema(Schema):
    defendants = fields.Pluck(DefendantSchema, 'id', many=True)

    amount_claimed = fields.Float()

    class Meta:
        fields = ("docket_id", "file_date", "status", "plaintiff_id", "court_date", "courtroom_id", "presiding_judge_id", "is_cares", "is_legacy",
                  "nonpayment", "amount_claimed", "amount_claimed_category", "defendants", "judgement", "notes")


detainer_warrant_schema = DetainerWarrantSchema()
detainer_warrants_schema = DetainerWarrantSchema(many=True)
detainer_warrant_edit_schema = DetainerWarrantEditSchema()
detainer_warrants_edit_schema = DetainerWarrantEditSchema(many=True)

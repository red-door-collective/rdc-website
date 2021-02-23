from . import api, ma

from flask import request
from flask_restful import Resource
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Plantiff, PhoneNumberVerification
from .schemas import *

class AttorneyListResource(Resource):
    def get(self):
        attorneys = Attorney.query.all()
        return attorneys_schema.dump(attorneys)

class AttorneyResource(Resource):
    def get(self, attorney_id):
        attorney = Attorney.query.get_or_404(attorney_id)
        return attorney_schema.dump(attorney)

api.add_resource(AttorneyListResource, '/attorneys')
api.add_resource(AttorneyResource, '/attorneys/<int:attorney_id>')

class DefendantListResource(Resource):
    def get(self):
        defendants = Defendant.query.all()
        return defendants_schema.dump(defendants)

class DefendantResource(Resource):
    def get(self, defendant_id):
        defendant = Defendant.query.get_or_404(defendant_id)
        return defendant_schema.dump(defendant)

api.add_resource(DefendantListResource, '/defendants')
api.add_resource(DefendantResource, '/defendants/<int:defendant_id>')

class CourtroomListResource(Resource):
    def get(self):
        courtrooms = Courtroom.query.all()
        return courtrooms_schema.dump(courtrooms)

class CourtroomResource(Resource):
    def get(self, courtroom_id):
        courtroom = Courtroom.query.get_or_404(courtroom_id)
        return courtroom_schema.dump(courtroom)

api.add_resource(CourtroomListResource, '/courtrooms')
api.add_resource(CourtroomResource, '/courtrooms/<int:courtroom_id>')

class PlantiffListResource(Resource):
    def get(self):
        plantiffs = Plantiff.query.all()
        return plantiffs_schema.dump(plantiffs)

class PlantiffResource(Resource):
    def get(self, plantiff_id):
        plantiff = Plantiff.query.get_or_404(plantiff_id)
        return plantiff_schema.dump(plantiff)

api.add_resource(PlantiffListResource, '/plantiffs')
api.add_resource(PlantiffResource, '/plantiffs/<int:plantiff_id>')

class JudgeListResource(Resource):
    def get(self):
        judges = Judge.query.all()
        return judges_schema.dump(judges)

class JudgeResource(Resource):
    def get(self, judge_id):
        judge = Judge.query.get_or_404(judge_id)
        return judge_schema.dump(judge)

api.add_resource(JudgeListResource, '/judges')
api.add_resource(JudgeResource, '/judges/<int:judge_id>')

class DetainerWarrantListResource(Resource):
    def get(self):
        detainer_warrants = DetainerWarrant.query.all()
        return detainer_warrants_schema.dump(detainer_warrants)

class DetainerWarrantResource(Resource):
    def get(self, detainer_warrant_id):
        detainer_warrant = DetainerWarrant.query.get_or_404(detainer_warrant_id)
        return detainer_warrant_schema.dump(detainer_warrant)

api.add_resource(DetainerWarrantListResource, '/detainer-warrants')
api.add_resource(DetainerWarrantResource, '/detainer-warrants/<int:detainer_warrant_id>')

class PhoneNumberVerificationListResource(Resource):
    def get(self):
        phones = PhoneNumberVerification.query.all()
        return phone_number_verifications_schema.dump(phones)

class PhoneNumberVerificationResource(Resource):
    def get(self, phone_number_verification_id):
         phone = PhoneNumberVerification.query.get_or_404(phone_number_verification_id)
         return phone_number_verification_schema.dump(phone)

api.add_resource(PhoneNumberVerificationListResource, '/phone-number-verifications')
api.add_resource(PhoneNumberVerificationResource, '/phone-number-verifications/<int:phone_number_verification_id>')

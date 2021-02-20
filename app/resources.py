from . import api, ma

from flask import request
from flask_restful import Resource
from .models import Defendant

class DefendantSchema(ma.Schema):
    class Meta:
        fields = ("id", "name", "phone", "address")

defendant_schema = DefendantSchema()
defendants_schema = DefendantSchema(many=True)

class DefendantListResource(Resource):
    def get(self):
        defendants = Defendant.query.all()
        return defendants_schema.dump(defendants)


class DefendantResource(Resource):
    def get(self, post_id):
        defendant = Defendant.query.get_or_404(post_id)
        return defendant_schema.dump(defendant)

api.add_resource(DefendantListResource, '/defendants')
api.add_resource(DefendantResource, '/defendants/<int:defendant_id>')

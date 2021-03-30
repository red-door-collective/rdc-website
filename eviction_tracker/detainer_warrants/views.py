import operator
from flask import Blueprint
from flask_security import current_user, AnonymousUser
from flask_resty import (
    ApiError,
    AuthorizeModifyMixin,
    HasAnyCredentialsAuthorization,
    HasCredentialsAuthorizationBase,
    HeaderAuthenticationBase,
    ColumnFilter,
    GenericModelView,
    CursorPaginationBase,
    RelayCursorPagination,
    Filtering,
    Sorting,
    meta,
    model_filter
)

from sqlalchemy import and_, or_
from sqlalchemy.orm import raiseload

from eviction_tracker.database import db
from .models import DetainerWarrant, Attorney, Defendant, Courtroom, Plantiff, Judge, PhoneNumberVerification
from .serializers import *
from eviction_tracker.permissions.api import HeaderUserAuthentication, Protected, OnlyMe, CursorPagination, AllowDefendant


class AttorneyResourceBase(GenericModelView):
    model = Attorney
    schema = attorney_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting('name', default='name')


class AttorneyListResource(AttorneyResourceBase):
    def get(self):
        return self.list()


class AttorneyResource(AttorneyResourceBase):
    def get(self, id):
        return self.retrieve(id)


class DefendantResourceBase(GenericModelView):
    model = Defendant
    schema = defendant_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting('name', default='name')


class DefendantListResource(DefendantResourceBase):
    def get(self):
        return self.list()


class DefendantResource(DefendantResourceBase):
    def get(self):
        return self.retrieve(id)


class CourtroomResourceBase(GenericModelView):
    model = Courtroom
    schema = courtroom_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting('name', default='name')


class CourtroomListResource(CourtroomResourceBase):
    def get(self):
        return self.list()


class CourtroomResource(CourtroomResourceBase):
    def get(self, id):
        return self.retrieve(id)


class PlantiffResourceBase(GenericModelView):
    model = Plantiff
    schema = plantiff_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting('name', default='name')


class PlantiffListResource(PlantiffResourceBase):
    def get(self):
        return self.list()


class PlantiffResource(PlantiffResourceBase):
    def get(self, id):
        return self.retrieve(id)


class JudgeResourceBase(GenericModelView):
    model = Judge
    schema = judge_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting('name', default='name')


class JudgeListResource(JudgeResourceBase):
    def get(self):
        return self.list()


class JudgeResource(JudgeResourceBase):
    def get(self, id):
        return self.retrieve(id)


@model_filter(fields.String())
def filter_defendant_name(model, defendant_name):
    return model.defendants.any(Defendant.name.ilike(f'%{defendant_name}%'))


class DetainerWarrantResourceBase(GenericModelView):
    model = DetainerWarrant
    schema = detainer_warrant_schema
    id_fields = ('docket_id',)

    authentication = HeaderUserAuthentication()
    authorization = AllowDefendant()

    pagination = CursorPagination()
    sorting = Sorting('file_date', default='file_date')
    filtering = Filtering(
        docket_id=ColumnFilter(operator.eq),
        defendant_name=filter_defendant_name,
        judgement=ColumnFilter(operator.eq)
    )


class DetainerWarrantListResource(DetainerWarrantResourceBase):
    def get(self):
        return self.list()


class DetainerWarrantResource(DetainerWarrantResourceBase):
    def get(self, id):
        return self.retrieve(id)


class PhoneNumberVerificationResourceBase(GenericModelView):
    model = PhoneNumberVerification
    schema = phone_number_verification_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting('phone_number', default='phone_number')


class PhoneNumberVerificationListResource(PhoneNumberVerificationResourceBase):
    def get(self):
        return self.list()


class PhoneNumberVerificationResource(PhoneNumberVerificationResourceBase):
    def get(self, id):
        return self.retrieve(id)

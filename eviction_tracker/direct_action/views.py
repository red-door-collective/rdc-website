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
from .models import Campaign, Event, PhoneBankEvent
from .serializers import *
from eviction_tracker.permissions.api import HeaderUserAuthentication, Protected, OnlyMe, CursorPagination, AllowDefendant


class CampaignResourceBase(GenericModelView):
    model = Campaign
    schema = campaign_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting('name', default='name')


class CampaignListResource(CampaignResourceBase):
    def get(self):
        return self.list()


class CampaignResource(CampaignResourceBase):
    def get(self, id):
        return self.retrieve(id)


class PhoneBankEventResourceBase(GenericModelView):
    model = PhoneBankEvent
    schema = phone_bank_event_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting('name', default='name')


class PhoneBankEventListResource(PhoneBankEventResourceBase):
    def get(self):
        return self.list()


class PhoneBankEventResource(PhoneBankEventResourceBase):
    def get(self, id):
        return self.retrieve(id)

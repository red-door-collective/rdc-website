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
    model_filter,
)

from sqlalchemy import and_, or_
from sqlalchemy.orm import raiseload

from rdc_website.database import db
from rdc_website.permissions.api import (
    HeaderUserAuthentication,
    Protected,
    CursorPagination,
)
from .models import User, Role
from .serializers import *


class UserResourceBase(GenericModelView):
    model = User
    schema = user_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting("id", default="-id")


class UserListResource(UserResourceBase):
    def get(self):
        return self.list()


class UserResource(UserResourceBase):
    def get(self, id):
        return self.retrieve(id)

    def patch(self, id):
        return self.update(int(id), partial=True)


class RoleResourceBase(GenericModelView):
    model = Role
    schema = role_schema

    authentication = HeaderUserAuthentication()
    authorization = Protected()

    pagination = CursorPagination()
    sorting = Sorting("id", default="-id")


class RoleListResource(RoleResourceBase):
    def get(self):
        return self.list()


class RoleResource(RoleResourceBase):
    def get(self, id):
        return self.retrieve(id)

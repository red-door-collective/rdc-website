from flask_security import current_user
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
    LimitPagination,
    Filtering,
    Sorting,
    meta,
    model_filter,
)
from rdc_website.detainer_warrants.models import DetainerWarrant, Defendant
from sqlalchemy import or_


class AllowDefendant(AuthorizeModifyMixin, HasCredentialsAuthorizationBase):
    @property
    def request_user_id(self):
        return self.get_request_credentials()["user_id"]

    def filter_query(self, query, view):
        if (
            current_user.has_role("Superuser")
            or current_user.has_role("Admin")
            or current_user.has_role("Organizer")
        ):
            return query

        try:
            return query.join(DetainerWarrant._defendants).filter(
                or_(
                    Defendant.first_name.ilike(f"%{current_user.first_name}%"),
                    Defendant.last_name.ilike(f"%{current_user.last_name}%"),
                )
            )
        except AttributeError:
            raise ApiError(403, {"code": "not a defendant"})

    def authorize_modify_item(self, item, action):
        if not self.request_user_id:
            raise ApiError(403, {"code": "invalid_user"})


class OnlyOrganizers(AuthorizeModifyMixin, HasCredentialsAuthorizationBase):
    @property
    def request_user_id(self):
        return self.get_request_credentials()["user_id"]

    def filter_query(self, query, view):
        if (
            current_user.has_role("Superuser")
            or current_user.has_role("Admin")
            or current_user.has_role("Organizer")
        ):
            return query

        else:
            raise ApiError(403, {"code": "insufficient_permissions"})

    def authorize_modify_item(self, item, action):
        if not self.request_user_id:
            raise ApiError(403, {"code": "invalid_user"})


class Protected(AuthorizeModifyMixin, HasCredentialsAuthorizationBase):
    @property
    def request_user_id(self):
        return self.get_request_credentials()["user_id"]

    def filter_query(self, query, view):
        return query

    def authorize_modify_item(self, item, action):
        user_id = self.request_user_id

        if not user_id:
            raise ApiError(403, {"code": "invalid_user"})


class PartnerProtected(AuthorizeModifyMixin, HasCredentialsAuthorizationBase):
    @property
    def request_user_id(self):
        return self.get_request_credentials()["user_id"]

    def filter_query(self, query, view):
        if (
            current_user.has_role("Superuser")
            or current_user.has_role("Admin")
            or current_user.has_role("Organizer")
            or current_user.has_role("Partner")
        ):
            return query

        else:
            raise ApiError(403, {"code": "insufficient_permissions"})

    def authorize_modify_item(self, item, action):
        user_id = self.request_user_id

        if not user_id:
            raise ApiError(403, {"code": "invalid_user"})


class HeaderUserAuthentication(HeaderAuthenticationBase):
    def get_credentials_from_token(self, token):
        return {"user_id": token}


class OnlyMe(AuthorizeModifyMixin, HasCredentialsAuthorizationBase):
    @property
    def request_user_id(self):
        return self.get_request_credentials()["user_id"]

    def filter_query(self, query, view):
        return query.filter_by(id=self.request_user_id)

    def authorize_modify_item(self, item, action):
        if not self.request_user_id:
            raise ApiError(403, {"code": "invalid_user"})


class CursorPagination(RelayCursorPagination, LimitPagination):
    # def get_limit(self):
    #     return 100

    def get_page(self, query, view):
        items = super().get_page(query, view)

        after_cursor = None
        if len(items) == self.get_limit():
            after_cursor = super().make_cursor(
                items[-1], view, super().get_field_orderings(view)
            )

        meta.update_response_meta({"after_cursor": after_cursor})
        meta.update_response_meta({"total_matches": query.count()})

        return items

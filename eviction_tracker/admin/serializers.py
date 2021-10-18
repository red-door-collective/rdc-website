from marshmallow import Schema, fields


class RoleSchema(Schema):
    class Meta:
        fields = ("id", "name", "description")


role_schema = RoleSchema()
roles_schemas = RoleSchema(many=True)


class UserSchema(Schema):
    roles = fields.Nested(RoleSchema, many=True)

    class Meta:
        fields = ("id", "name", "first_name", "last_name",
                  "roles", "active", "preferred_navigation")


user_schema = UserSchema()
user_schemas = UserSchema(many=True)

"""empty message

Revision ID: f019e4f1d25c
Revises: a72b9feecf0d
Create Date: 2021-07-29 11:41:16.577221

"""
from alembic import op
import sqlalchemy as sa
from datetime import datetime

# revision identifiers, used by Alembic.
revision = 'f019e4f1d25c'
down_revision = 'a72b9feecf0d'
branch_labels = None
depends_on = None

now = sa.text('now()')
bad_now = str(datetime.now())


def upgrade():
    op.drop_column('phone_number_verifications', 'updated_at')
    op.drop_column('phone_number_verifications', 'created_at')
    op.drop_column('judges', 'updated_at')
    op.drop_column('judges', 'created_at')
    op.drop_column('districts', 'updated_at')
    op.drop_column('districts', 'created_at')
    op.drop_column('detainer_warrants', 'updated_at')
    op.drop_column('detainer_warrants', 'created_at')
    op.drop_column('defendants', 'updated_at')
    op.drop_column('defendants', 'created_at')
    op.drop_column('courtrooms', 'updated_at')
    op.drop_column('courtrooms', 'created_at')
    op.drop_column('attorneys', 'updated_at')
    op.drop_column('attorneys', 'created_at')
    op.add_column('attorneys', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('attorneys', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('courtrooms', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('courtrooms', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('defendants', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('defendants', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('detainer_warrants', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('detainer_warrants', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('districts', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('districts', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('judges', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('judges', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('phone_number_verifications', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=now))
    op.add_column('phone_number_verifications', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=now))


def downgrade():
    op.drop_column('phone_number_verifications', 'updated_at')
    op.drop_column('phone_number_verifications', 'created_at')
    op.drop_column('judges', 'updated_at')
    op.drop_column('judges', 'created_at')
    op.drop_column('districts', 'updated_at')
    op.drop_column('districts', 'created_at')
    op.drop_column('detainer_warrants', 'updated_at')
    op.drop_column('detainer_warrants', 'created_at')
    op.drop_column('defendants', 'updated_at')
    op.drop_column('defendants', 'created_at')
    op.drop_column('courtrooms', 'updated_at')
    op.drop_column('courtrooms', 'created_at')
    op.drop_column('attorneys', 'updated_at')
    op.drop_column('attorneys', 'created_at')
    op.add_column('attorneys', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('attorneys', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('courtrooms', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('courtrooms', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('defendants', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('defendants', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('detainer_warrants', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('detainer_warrants', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('districts', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('districts', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('judges', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('judges', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('phone_number_verifications', sa.Column(
        'created_at', sa.DateTime(), nullable=False, server_default=bad_now))
    op.add_column('phone_number_verifications', sa.Column(
        'updated_at', sa.DateTime(), nullable=False, server_default=bad_now))

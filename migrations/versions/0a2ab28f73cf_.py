"""empty message

Revision ID: 0a2ab28f73cf
Revises: c157d9ddb430
Create Date: 2021-03-22 14:16:38.419665

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0a2ab28f73cf'
down_revision = 'c157d9ddb430'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.add_column('detainer_warrants', sa.Column('notes', sa.String(length=255), nullable=True))
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('detainer_warrants', 'notes')
    # ### end Alembic commands ###
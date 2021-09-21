"""empty message

Revision ID: d30568c05df2
Revises: d6e31f9483cd
Create Date: 2021-09-20 23:02:59.634961

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd30568c05df2'
down_revision = 'd6e31f9483cd'
branch_labels = None
depends_on = None

pair = ['name', 'district_id']
names = ['first_name', 'middle_name', 'last_name',
         'suffix', 'district_id']


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_unique_constraint(None, 'attorneys', ['name', 'district_id'])
    op.create_unique_constraint(None, 'courtrooms', ['name', 'district_id'])
    op.create_unique_constraint(None, 'defendants', [
                                'first_name', 'middle_name', 'last_name', 'suffix', 'address', 'district_id'])
    op.create_unique_constraint(None, 'districts', ['name'])
    op.create_unique_constraint(None, 'judges', ['name', 'district_id'])
    op.create_unique_constraint(None, 'plaintiffs', ['name', 'district_id'])
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_constraint(None, 'plaintiffs', type_='unique')
    op.drop_constraint(None, 'judges', type_='unique')
    op.drop_constraint(None, 'districts', type_='unique')
    op.drop_constraint(None, 'defendants', type_='unique')
    op.drop_constraint(None, 'courtrooms', type_='unique')
    op.drop_constraint(None, 'attorneys', type_='unique')
    # ### end Alembic commands ###
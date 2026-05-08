"""add users and record ownership

Revision ID: 202605030001
Revises: 202604260001
Create Date: 2026-05-03
"""
from collections.abc import Sequence
import os

from alembic import op
import bcrypt
import sqlalchemy as sa

revision: str = "202605030001"
down_revision: str | None = "202604260001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("hashed_password", sa.String(length=255), nullable=False),
        sa.Column("display_name", sa.String(length=80), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_index(op.f("ix_users_id"), "users", ["id"], unique=False)

    op.add_column("cooking_records", sa.Column("user_id", sa.Integer(), nullable=True))
    op.create_index(
        op.f("ix_cooking_records_user_id"),
        "cooking_records",
        ["user_id"],
        unique=False,
    )

    users = sa.table(
        "users",
        sa.column("id", sa.Integer),
        sa.column("email", sa.String),
        sa.column("hashed_password", sa.String),
        sa.column("display_name", sa.String),
    )
    cooking_records = sa.table(
        "cooking_records",
        sa.column("user_id", sa.Integer),
    )

    legacy_password = os.getenv("HAEMEOKNOTE_LEGACY_USER_PASSWORD")
    legacy_password_hash = (
        bcrypt.hashpw(legacy_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        if legacy_password
        else "legacy-login-disabled"
    )
    op.bulk_insert(
        users,
        [
            {
                "id": 1,
                "email": "local@haemeoknote.local",
                "hashed_password": legacy_password_hash,
                "display_name": "해먹노트 사용자",
            }
        ],
    )
    op.execute(
        "SELECT setval(pg_get_serial_sequence('users', 'id'), "
        "COALESCE((SELECT MAX(id) FROM users), 1), true)"
    )
    op.execute(cooking_records.update().values(user_id=1))
    op.alter_column("cooking_records", "user_id", nullable=False)
    op.create_foreign_key(
        op.f("fk_cooking_records_user_id_users"),
        "cooking_records",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("fk_cooking_records_user_id_users"),
        "cooking_records",
        type_="foreignkey",
    )
    op.drop_index(op.f("ix_cooking_records_user_id"), table_name="cooking_records")
    op.drop_column("cooking_records", "user_id")
    op.drop_index(op.f("ix_users_id"), table_name="users")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")

from models.account import Account
from repositories.AccountRepository import AccountRepository
from repositories.UserRepository import UserRepository


class AccountService:
    def __init__(self, account_repository=None, user_repository=None):
        """Use MongoDB repositories by default, or injected repositories in tests."""
        self.account_repository = (
            account_repository
            if account_repository is not None
            else AccountRepository()
        )
        self.user_repository = (
            user_repository
            if user_repository is not None
            else UserRepository()
        )

    def create_account(self, user_id, account_type):
        # Check if account type is valid
        if not isinstance(account_type, str):
            raise ValueError("Account type must be CHECKING or SAVINGS")

        account_type = account_type.strip().upper()

        if account_type not in ["CHECKING", "SAVINGS"]:
            raise ValueError("Account type must be CHECKING or SAVINGS")

        if user_id is None or not isinstance(user_id, int) or user_id <= 0:
            raise ValueError("User ID must be a positive integer")

        if self.user_repository.get_by_id(user_id) is None:
            raise ValueError("User not found")

        existing_account = self.account_repository.get_by_user_and_type(
            user_id,
            account_type,
        )

        if existing_account is not None:
            raise ValueError(f"User already has a {account_type} account")

        account = Account(user_id, account_type)
        return self.account_repository.save(account)

    def get_account(self, account_id):
        # Get an account by its ID from the repository.

        account = self.account_repository.get_by_id(account_id)

        if account is None:
            raise ValueError("Account not found")

        return account

    def get_all_accounts(self):
        # Return all accounts from the repository.
        return self.account_repository.get_all()

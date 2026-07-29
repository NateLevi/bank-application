from models.account import Account
from repositories.mongo import get_database, get_next_sequence


class AccountRepository:
    def __init__(self, database=None, sequence_generator=None):
        # Use the real MongoDB database by default. Tests can provide a fake one.
        self.database = database if database is not None else get_database()
        self.collection = self.database["accounts"]
        self._next_sequence = sequence_generator or get_next_sequence

    @staticmethod
    def _to_document(account):
        """Convert an Account model into the dictionary MongoDB stores."""
        return {
            "account_id": account.account_id,
            "user_id": account.user_id,
            "account_type": account.account_type,
            "balance": account.balance,
            "created_at": account.created_at,
        }

    @staticmethod
    def _to_model(document):
        """Convert a MongoDB document into an Account model."""
        if document is None:
            return None

        account = Account(
            account_id=document["account_id"],
            user_id=document["user_id"],
            account_type=document["account_type"],
            balance=document.get("balance", 0.0),
        )

        # Preserve the original creation time instead of generating a new one.
        if document.get("created_at") is not None:
            account.created_at = document["created_at"]

        return account

    def save(self, account):
        # MongoDB creates _id automatically; our counter creates the public ID.
        if account.account_id is None:
            account.account_id = self._next_sequence("account_id")

        self.collection.insert_one(self._to_document(account))
        return account

    def get_by_id(self, account_id):
        document = self.collection.find_one({"account_id": account_id})
        return self._to_model(document)

    def get_all(self):
        documents = self.collection.find().sort("account_id", 1)
        return [self._to_model(document) for document in documents]

    def get_by_user_and_type(self, user_id, account_type):
        document = self.collection.find_one(
            {
                "user_id": user_id,
                "account_type": account_type,
            }
        )
        return self._to_model(document)

from models.user import User
from repositories.mongo import get_database, get_next_sequence


class UserRepository:
    def __init__(self, database=None, sequence_generator=None):
        # Use the real MongoDB database by default. Tests can provide a fake one.
        self.database = database if database is not None else get_database()
        self.collection = self.database["users"]
        self._next_sequence = sequence_generator or get_next_sequence

    @staticmethod
    def _to_document(user):
        """Convert a User model into the dictionary MongoDB stores."""
        return {
            "user_id": user.user_id,
            "name": user.name,
            "email": user.email,
            "created_at": user.created_at,
        }

    @staticmethod
    def _to_model(document):
        """Convert a MongoDB document into a User model."""
        if document is None:
            return None

        return User(
            user_id=document["user_id"],
            name=document["name"],
            email=document["email"],
            created_at=document.get("created_at"),
        )

    def save(self, user):
        # MongoDB creates _id automatically; our counter creates the public ID.
        if user.user_id is None:
            user.user_id = self._next_sequence("user_id")

        self.collection.insert_one(self._to_document(user))
        return user

    def get_by_id(self, user_id):
        document = self.collection.find_one({"user_id": user_id})
        return self._to_model(document)

    def get_all(self):
        documents = self.collection.find().sort("user_id", 1)
        return [self._to_model(document) for document in documents]

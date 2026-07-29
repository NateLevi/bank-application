import os
from functools import lru_cache
from pathlib import Path
from dotenv import load_dotenv
from pymongo import ASCENDING, MongoClient, ReturnDocument


## load in env mongodb username/password
load_dotenv(
    Path(__file__).resolve().parent.parent / "atlas-credentials.env"
)


@lru_cache(maxsize=1)
def get_database():
    # Read the sensitive MongoDB connection URI from the credentials file.
    mongodb_uri = os.getenv("MONGODB_URI")

    if not mongodb_uri:
        raise ValueError(
            "MONGODB_URI is not set. Add it to atlas-credentials.env."
        )

    # Create one client/database object and reuse it.
    client = MongoClient(mongodb_uri)
    database = client["bank_application"]

    # Make sure required indexes exist before repositories use collections.
    _ensure_indexes(database)
    return database


def _ensure_indexes(database):
    # Unique indexes keep our numeric IDs from duplicating.
    database["accounts"].create_index(
        [("account_id", ASCENDING)], unique=True
    )
    database["users"].create_index([("user_id", ASCENDING)], unique=True)
    database["transactions"].create_index(
        [("transaction_id", ASCENDING)], unique=True
    )

    # Query helper index for account transaction history lookups.
    database["transactions"].create_index(
        [("account_id", ASCENDING), ("created_at", ASCENDING)]
    )

    # Counter collection is used for auto-increment style numeric IDs.
    database["counters"].create_index([("_id", ASCENDING)], unique=True)


def get_next_sequence(sequence_name: str) -> int:
    # Atomically increment and return the next numeric ID.
    counter = get_database()["counters"].find_one_and_update(
        {"_id": sequence_name},
        {"$inc": {"value": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    return int(counter["value"])

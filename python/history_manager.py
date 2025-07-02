# _implementation/python/history_manager.py
# This file defines the HistoryManager class, which is responsible for
# managing the state history of the application using a SQLite database.
# It provides methods to create the database, commit new states, and
# retrieve parent states for the undo functionality.

import sqlite3
import json
import uuid

class HistoryManager:
    """
    Manages the state history of a project in a SQLite database.
    This class abstracts the database operations for creating a state tree,
    allowing for undo functionality and preserving a non-linear history.
    """
    def __init__(self, database_path):
        """
        Initializes the HistoryManager with a path to a SQLite database.

        Args:
            database_path (str): The file path for the SQLite database.
        """
        self.database_path = database_path
        self.conn = None
        self.connect()
        self.create_table()

    def connect(self):
        """
        Establishes a connection to the SQLite database.
        """
        self.conn = sqlite3.connect(self.database_path, check_same_thread=False)

    def create_table(self):
        """
        Creates the 'state_tree' table if it does not already exist.
        The table stores the nodes of the state history tree.
        """
        with self.conn:
            self.conn.execute("""
                CREATE TABLE IF NOT EXISTS state_tree (
                    node_id TEXT PRIMARY KEY,
                    parent_id TEXT,
                    state_snapshot TEXT,
                    FOREIGN KEY (parent_id) REFERENCES state_tree(node_id)
                )
            """)

    def commit(self, state_snapshot: dict, parent_id: str | None) -> str:
        """
        Commits a new state to the history tree, generating a new ID for it.

        Args:
            state_snapshot (dict): A JSON-serializable dictionary representing the application state.
                                   This dict will be mutated to include the new history_node_id.
            parent_id (str | None): The ID of the parent state node. None for the initial commit.

        Returns:
            str: The unique ID of the newly created state node.
        """
        node_id = str(uuid.uuid4())
        state_snapshot["history_node_id"] = node_id  # Mutate the state with its new ID

        state_json = json.dumps(state_snapshot)
        with self.conn:
            self.conn.execute(
                "INSERT INTO state_tree (node_id, parent_id, state_snapshot) VALUES (?, ?, ?)",
                (node_id, parent_id, state_json)
            )
        return node_id

    def get_state(self, node_id: str) -> dict | None:
        """
        Retrieves a state snapshot by its node ID.

        Args:
            node_id (str): The ID of the state node to retrieve.

        Returns:
            dict | None: The state snapshot as a dictionary, or None if not found.
        """
        cursor = self.conn.execute("SELECT state_snapshot FROM state_tree WHERE node_id = ?", (node_id,))
        row = cursor.fetchone()
        if row:
            return json.loads(row[0])
        return None

    def update_state(self, node_id: str, state_snapshot: dict):
        """
        Updates the state snapshot for an existing node.
        This is useful for the initial root node creation, where the node's own
        ID needs to be stored within its state snapshot.

        Args:
            node_id (str): The ID of the state node to update.
            state_snapshot (dict): The new state snapshot to save.
        """
        state_json = json.dumps(state_snapshot)
        with self.conn:
            self.conn.execute(
                "UPDATE state_tree SET state_snapshot = ? WHERE node_id = ?",
                (state_json, node_id)
            )

    def get_parent(self, node_id: str) -> dict | None:
        """
        Retrieves the parent state of a given node.

        Args:
            node_id (str): The ID of the node whose parent is to be retrieved.

        Returns:
            dict | None: The parent state snapshot as a dictionary, or None if the node or its parent is not found.
        """
        # First, find the parent_id
        cursor = self.conn.execute("SELECT parent_id FROM state_tree WHERE node_id = ?", (node_id,))
        row = cursor.fetchone()
        if row and row[0]:
            parent_id = row[0]
            # Then, get the state for that parent_id
            return self.get_state(parent_id)
        return None

    def get_parent_id(self, node_id: str) -> str | None:
        """
        Retrieves the parent ID of a given node.

        Args:
            node_id (str): The ID of the node whose parent ID is to be retrieved.

        Returns:
            str | None: The parent node's ID, or None if not found.
        """
        cursor = self.conn.execute("SELECT parent_id FROM state_tree WHERE node_id = ?", (node_id,))
        row = cursor.fetchone()
        if row:
            return row[0]
        return None

    def get_root_node_id(self) -> str | None:
        """
        Finds the ID of the root node (the one with no parent).
        Assumes there is only one root node.
        """
        cursor = self.conn.execute("SELECT node_id FROM state_tree WHERE parent_id IS NULL")
        row = cursor.fetchone()
        if row:
            return row[0]
        return None

    def close(self):
        """
        Closes the database connection.
        """
        if self.conn:
            self.conn.close() 
async function ensureUserProfile(db, identity, timestamp) {
    const ref = db.collection("users").doc(identity.uid);
    let snapshot = await ref.get();
    if (!snapshot.exists) {
        const fields = { email: identity.email || "", createdAt: timestamp(), updatedAt: timestamp() };
        try {
            await ref.create(fields);
            return fields;
        } catch (error) {
            // Another authenticated request may have initialized the same account.
            if (error.code !== 6 && error.code !== "already-exists") throw error;
            snapshot = await ref.get();
            if (!snapshot.exists) throw error;
        }
    }
    return snapshot.data();
}

module.exports = { ensureUserProfile };

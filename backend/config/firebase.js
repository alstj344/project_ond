const { initializeApp, cert, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { existsSync } = require("node:fs");
const path = require("node:path");

// Production uses the hosting service identity, never a bundled private key.
const localKey = path.join(__dirname, "../serviceAccountKey.json");
const useLocalKey = process.env.NODE_ENV !== "production" && !process.env.GOOGLE_APPLICATION_CREDENTIALS && existsSync(localKey);
initializeApp({
    credential: useLocalKey ? cert(require(localKey)) : applicationDefault(),
    projectId: process.env.FIREBASE_PROJECT_ID || "project-ond"
});

const db = getFirestore(process.env.FIRESTORE_DATABASE_ID || "ond-db");

module.exports = db;

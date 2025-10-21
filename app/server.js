// app/server.js
import express from "express";
import os from "os";

const app = express();
const PORT = 8080;
const HOST = "0.0.0.0"; // <-- bind to all interfaces
const hostname = os.hostname();

// Generate a random ID once when the container starts
const instanceID = Math.floor(Math.random() * 1000000);

app.get("/", (req, res) => {
  res.send(`
    Server is running inside Docker on port 8080 typeshit 🚀. <br>
    Unique instance ID: ${instanceID} <br>
    Container hostname: ${hostname}
  `);
});

app.listen(PORT, HOST, () => {
  console.log(`Server is running on ${HOST}:${PORT}, instance ID: ${instanceID}`);
});


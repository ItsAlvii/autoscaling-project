// app/server.js
import express from "express";
import os from "os";

const app = express();
const PORT = 8080;

// Get this machine's hostname (unique per EC2 instance)
const hostname = os.hostname();

app.get("/", (req, res) => {
  res.send(`Server is running inside Docker on port 8080 🚀. 
This is version 3.
Served from instance: ${hostname}`);
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT} (instance: ${hostname})`);
});


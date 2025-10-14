// app/server.js
import express from "express";

const app = express();
const PORT = 8080;

app.get("/", (req, res) => {
  res.send("Server is running inside Docker on port 8080 🚀. This is version 3");
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});


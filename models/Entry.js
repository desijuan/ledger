const mongoose = require("mongoose");

const EntrySchema = new mongoose.Schema({
  from: {
    type: String,
    required: true,
    trim: true,
    maxlength: 20
  },
  to: {
    type: String,
    required: true,
    trim: true,
    maxlength: 20
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  description: {
    type: String,
    trim: true,
    maxlength: 300
  },
  date: {
    type: Date,
    reuired: true,
    default: Date.now
  }
});

module.exports = mongoose.model('Entry', EntrySchema);
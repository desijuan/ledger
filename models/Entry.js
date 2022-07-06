const mongoose = require("mongoose");

const EntrySchema = new mongoose.Schema({
  from: {
    type: String,
    required: true,
    trim: true,
    maxlength: [20, 'Name cannot be more than 20 characters']
  },
  to: {
    type: String,
    required: true,
    trim: true,
    maxlength: [20, 'Name cannot be more than 20 characters']
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  date: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Entry', EntrySchema);
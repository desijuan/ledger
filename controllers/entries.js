const Entry = require('../models/Entry');
const CustomAPIError = require('../errors/custon-error');

const getAllEntries = async (req, res) => {
  const entries = await Entry.find({});
  res.status(200).json({ entries });
};

const createEntry = async (req, res) => {
  const entry = await Entry.create(req.body);
  res.status(201).json({ entry });
};

const getEntry = async (req, res, next) => {
  const entryID = req.params.id;
  const entry = await Entry.findById(entryID);
  if (!entry) throw new CustomAPIError(`No entry with id ${entryID}`, 404);
  res.status(200).json({ entry });
};

const updateEntry = async (req, res) => {
  const entryID = req.params.id;
  const entry = await Entry.findByIdAndUpdate(entryID, req.body, {
    new: true,
    runValidators: true
  });
  if (!entry) throw new CustomAPIError(`No entry with id ${entryID}`, 404);
  res.status(200).json({ entry });
};

const deleteEntry = async (req, res) => {
  const entryID = req.params.id;
  const entry = await Entry.findByIdAndDelete(entryID);
  if (!entry) throw new CustomAPIError(`No entry with id ${entryID}`, 404);
  res.status(200).json({ entry });
};

module.exports = {
  getAllEntries,
  createEntry,
  getEntry,
  updateEntry,
  deleteEntry
};

const { response } = require('express');
const Entry = require('../models/Entry');
const asyncWrapper = require('../middleware/async');
const { createCustomError } = require('../errors/custon-error');

const getAllEntries = asyncWrapper(async (req, res) => {
  const entries = await Entry.find({});
  res.status(200).json({ entries });
});

const createEntry = asyncWrapper(async (req, res) => {
  const entry = await Entry.create(req.body);
  res.status(201).json({ entry });
});

const getEntry = asyncWrapper(async (req, res, next) => {
  const entryID = req.params.id;
  const entry = await Entry.findById(entryID);
  if (!entry) {
    return next(createCustomError(`No entry with id: ${entryID}`, 404))
  };
  res.status(200).json({ entry });
});

const updateEntry = asyncWrapper(async (req, res) => {
  const entryID = req.params.id;
  const entry = await Entry.findByIdAndUpdate(entryID, req.body, {
    new: true,
    runValidators: true
  });
  if (!entry) {
    return next(createCustomError(`No entry with id: ${entryID}`, 404))
  };
  res.status(200).json({ entry });
});

const deleteEntry = asyncWrapper(async (req, res) => {
  const entryID = req.params.id;
  const entry = await Entry.findByIdAndDelete(entryID);
  if (!entry) {
    return next(createCustomError(`No entry with id: ${entryID}`, 404))
  };
  res.status(200).json({ entry });
});

module.exports = {
  getAllEntries,
  createEntry,
  getEntry,
  updateEntry,
  deleteEntry
};
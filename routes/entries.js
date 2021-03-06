const express = require('express');
const router = express.Router();

const {
  getAllEntries,
  createEntry,
  getEntry,
  updateEntry,
  deleteEntry
} = require('../controllers/entries');

router.route('/').get(getAllEntries).post(createEntry);
router.route('/:id').get(getEntry).patch(updateEntry).delete(deleteEntry);

module.exports = router;
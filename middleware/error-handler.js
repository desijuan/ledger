const { CustomAPIError } = require('../errors/custon-error')

const errorHandler = (err, req, res, next) => {
  console.log(err);
  if (err instanceof CustomAPIError) {
    return res.status(err.statusCode).json({ msg: err.message });
  };
  return res.status(500).json({ msg: 'Oops!' })
};

module.exports = errorHandler;
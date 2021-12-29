/* Table that contains customer and address data */
CREATE TABLE IF NOT EXISTS customer (
  CustomerID INTEGER NOT NULL AUTO_INCREMENT,
  CreatedAt timestamp DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  Firstname CHAR(40) NOT NULL,
  Lastname CHAR(40) NOT NULL,
  Email CHAR(64) NOT NULL,
  Taxvat CHAR(64),
  Street CHAR(64) NOT NULL,
  HouseNumber CHAR(10) NOT NULL,
  City CHAR(64) NOT NULL,
  Postcode CHAR(5) NOT NULL,
  CountryCode CHAR(5) NOT NULL,
  Telephone CHAR(40) NOT NULL,
  PRIMARY KEY (CustomerID),
  CONSTRAINT email_unique UNIQUE (Email)
) ENGINE=InnoDB;

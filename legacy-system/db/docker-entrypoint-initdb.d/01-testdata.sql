/* Customer test data */
BEGIN;
INSERT INTO customer
  (Firstname, Lastname, Email, Taxvat, Street, HouseNumber, City, Postcode, CountryCode, Telephone)
VALUES 
  ("Alice", "Science", "firstuser@example.com", "112033100065/DE263048799", "Eine Strasse", "42", "Zweibruecken", "66482", "DE", "014788899565");
COMMIT;

BEGIN;
INSERT INTO customer
  (Firstname, Lastname, Email, Taxvat, Street, HouseNumber, City, Postcode, CountryCode, Telephone)
VALUES 
  ("Bob", "Crypt", "seconduser@example.com", "322033100065/DE263048777", "Eine andere Strasse", "7", "Frankfurt am Main", "60385", "DE", "012347788994");
COMMIT;

#simple AD query
#pulls the following pieces of information for ALL AD USERS
#	DistinguishedName
#	FacsimileTelephoneNumber
#	GivenName
#	HomePhone
#	Mobile
#	Name
#	ObjectClass
#	ObjectGUID
#	OtherTelephone (see below for details)
#	SamAccountName
#	SID
#	Surname
#	TelephoneNumber
#	Organization
#	UserPrincipalName
#These properties can be excluded as needed, others can be added, they can also be reordered.
#the 'othertelephone is unique in that it can contain multiple values and is pulled as an array.
#	This will name the row in each query 'othertelephone' (n='othertelephone') and then the array is split apart and the elements are 
#	contstructed into in a single string, with a semi-colon and space between them.

get-aduser -fi * -properties * | select DistinguishedName, Enabled, facsimileTelephoneNumber, GivenName, HomePhone, Mobile, Name, ObjectClass, `
	ObjectGUID, @{n='otherTelephone'; e={$_.othertelephone -join'; '}}, SamAccountName, SID, Surname, TelephoneNumber, Organization, `
	UserPrincipalName |export-csv adResult.csv
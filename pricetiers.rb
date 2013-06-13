# Read a saved copy of iTunes Connect HTML and print price tier information in 
# SQL to stdout
#
# Usage: ruby #{$0} path/to/file.HTML

require 'nokogiri'

html_file = ARGV.shift

html = Nokogiri::HTML(open(html_file))
table = html.css("table")[0]

countries = []
Stages = [:country, :header, :content]
stage = Stages[0]

table.css("tr").each_with_index do |tr, row_index|
	tr.css("td").each_with_index do |td, col_index|
		case stage
			when :country
				if (td.attr("colspan"))
					country = {}
					country[:name], country[:currency] = *(td.inner_html.split(" - "))
					countries.push(country)
				end
			when :header

			when :content
				if col_index == 0
					;
				else
					col = col_index - 1
					tier = row_index - 1
					country = countries[(col/2).to_i]
					if not country.nil? and col%2==0
						country[:tiers] ||= []
						country[:tiers][tier] = td.inner_html
					end
				end
		end
	end

	stage = :content if stage == :header
	stage = :header if stage == :country
end

countries.each { |country| country[:tiers].reject! { |x| x.nil? } }

# OK, we have price tiers organised into something we can read. Build SQL!

sql = []
# Schemas

# Country schema
sql.push <<SQL
CREATE TABLE  `countries` (
`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY ,
`name` VARCHAR( 256 ) NOT NULL ,
`currency` VARCHAR( 10 ) NOT NULL ,
`symbol` VARCHAR( 10 ) NOT NULL ,
`before` TINYINT( 1 ) NOT NULL
) ENGINE = MYISAM ;
SQL

# Tier schema
sql.push <<SQL
CREATE TABLE  `distantstar`.`price_tiers` (
`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY ,
`country_id` TINYINT NOT NULL ,
`price` DOUBLE NOT NULL ,
`tier_id` TINYINT NOT NULL
) ENGINE = MYISAM ;
SQL
sql.clear

def hash_to_sql(hash, table)
	keys = hash.keys.map { |key| "`#{key}`" }.join(", ")
	values = hash.keys.map { |key| "'#{hash[key]}'" }.join(", ")
	return "INSERT INTO #{table} (#{keys}) VALUES (#{values});"
end

# Insert countries
countries.each_with_index do |country, index|
	hash = {
		"id" => index+1,
		"name" => country[:name],
		"currency" => country[:currency],
		"symbol" => ""
	}
	country[:id] = index+1
	sql.push hash_to_sql(hash, "countries")
end

# Insert tiers
countries.each do |country|
	country[:tiers].each_with_index do |price, tier|
		sql.push hash_to_sql({"country_id" => country[:id], "price" => price.to_f, "tier_id" => tier}, "price_tiers")
	end
end

puts sql.join("\n")
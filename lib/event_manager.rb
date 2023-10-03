require 'csv'
require 'date'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

# output multiple html files using csv data and erb template
def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

# format phone number
def clean_phone(home_phone)
  home_phone_no_space = home_phone.strip.gsub(/[^\d]/, '')
  if home_phone_no_space.length > 11 || home_phone_no_space.length < 10 || (home_phone_no_space.length == 11 && home_phone_no_space[0] != "1")
    '0000000000'
  elsif home_phone_no_space.length == 11 && home_phone_no_space[0] == '1'
    home_phone[1..]
  else
    home_phone_no_space
  end
end

# print a csv list of name, formatted phone number to /output
def save_phonelist(contents)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = 'output/phonelist.csv'
  # write header row to csv
  CSV.open(filename, 'w') do |csv|
    csv << ['First Name', 'Last Name', 'Phone Number']
    # write each row data to csv
    contents.each do |row|
      first = row[:first_name]
      last = row[:last_name]
      phone = clean_phone(row[:homephone])
      csv << [first, last, phone]
    end
  end
  puts "Phone list saved to #{filename}"
end

# returns hour as a string 24hr time
def popular_hour(dates)
  hour_histogram = Hash.new(0)
  dates.each do |date|
    hour = date.hour
    hour_histogram[hour] += 1
  end
  hour_histogram.max_by { |_hour, count| count }[0] # return only day [0]
end

# returns day of the week as number 0=Sun
def popular_day(dates)
  day_histogram = Hash.new(0)
  dates.each do |date|
    day = date.wday
    day_histogram[day] += 1
  end
  day_histogram.max_by { |_day, count| count }[0] #return only day at [0]
end

# returns time objects formatted from string in csv
def extract_dates(contents)
  parsed_dates = []
  contents.each do |item|
    parsed_dates << (DateTime.strptime(item[:regdate], '%m/%d/%y %H:%M'))
  end
  parsed_dates
end

puts 'EventManager initialized.'

contents = CSV.read(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

extracted_dates = extract_dates(contents)
most_popular_registration_hour = popular_hour(extracted_dates)
most_popular_registration_day = popular_day(extracted_dates) 

# hash to convert #wday
day_numbers = {
  0 => "Sunday",
  1 => "Monday",
  2 => "Tuesday",
  3 => "Wednesday",
  4 => "Thursday",
  5 => "Friday",
  6 => "Saturday"
}

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

# make mailed letters
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id,form_letter)
  puts "Letter #{id} saved."
end

save_phonelist(contents) # Assignment 1
puts "The most popular registration hour is #{most_popular_registration_hour}:00" # Assignment 2
puts "The most popular registration day is #{day_numbers[most_popular_registration_day]}" # Assignment 3

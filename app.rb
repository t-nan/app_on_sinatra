require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader'
require 'sqlite3'
require 'sequel'
require './operation.rb'
require './submit.rb'
require 'pry'

DB = Sequel.connect(adapter: 'sqlite', database: './test.db')
USER = DB[:user]
PRODUCT = DB[:product]
TEMPLATE = DB[:template]
OPERATION = DB[:operation]


post '/operation' do
  data = JSON.parse(request.body.read)
  item = data["item"][0]["request"]["body"]["raw"]
  request = JSON.parse(item)
  result = Operation.new(request).products_info.result
  return json(result)
end


post '/submit' do
  data = JSON.parse(request.body.read)
  item = data["item"][1]["request"]["body"]["raw"]
  request = JSON.parse(item)
  result = Submit.new(request).update_entries.result
  return json(result)
end

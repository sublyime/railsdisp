#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class RealTimeDispersionTest
  def initialize
    @base_url = 'http://localhost:3000'
  end

  def run_tests
    puts "🔄 Testing Real-Time Dispersion System..."
    puts "=" * 50
    
    tests = [
      [:test_dashboard_loads, "Dashboard loads successfully"],
      [:test_api_endpoints, "API endpoints respond correctly"],
      [:test_dispersion_events, "Dispersion events API"],
      [:test_weather_data, "Weather data API"]
    ]
    
    passed = 0
    failed = 0
    
    tests.each do |test_method, description|
      print "Testing: #{description}... "
      begin
        result = send(test_method)
        if result
          puts "✅ PASS"
          passed += 1
        else
          puts "❌ FAIL"
          failed += 1
        end
      rescue => e
        puts "❌ ERROR: #{e.message}"
        failed += 1
      end
    end
    
    puts "=" * 50
    puts "Results: #{passed} passed, #{failed} failed"
    puts "Success rate: #{(passed.to_f / (passed + failed) * 100).round(1)}%"
  end

  private

  def test_dashboard_loads
    uri = URI("#{@base_url}/")
    response = Net::HTTP.get_response(uri)
    response.code == '200'
  end

  def test_api_endpoints
    uri = URI("#{@base_url}/api/v1/dispersion_events")
    response = Net::HTTP.get_response(uri)
    return false unless response.code == '200'
    
    data = JSON.parse(response.body)
    data.is_a?(Hash) && data.key?('status') && data['status'] == 'success'
  end

  def test_dispersion_events
    uri = URI("#{@base_url}/api/v1/dispersion_events")
    response = Net::HTTP.get_response(uri)
    return false unless response.code == '200'
    
    data = JSON.parse(response.body)
    data.is_a?(Hash) && data.key?('data') && data['data'].is_a?(Array)
  end

  def test_weather_data
    uri = URI("#{@base_url}/api/v1/weather")
    response = Net::HTTP.get_response(uri)
    return false unless response.code == '200'
    
    data = JSON.parse(response.body)
    data.is_a?(Hash) && data.key?('status') && data['status'] == 'success'
  end
end

# Check if Rails server is running
begin
  uri = URI('http://localhost:3000')
  Net::HTTP.get_response(uri)
  puts "✅ Rails server is running"
  
  # Run tests
  test = RealTimeDispersionTest.new
  test.run_tests
rescue Errno::ECONNREFUSED
  puts "❌ Rails server is not running. Please start it with: rails server"
  exit 1
end
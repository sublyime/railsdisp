require "test_helper"

class WeatherDataControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get weather_data_index_url
    assert_response :success
  end

  test "should get show" do
    get weather_data_show_url
    assert_response :success
  end

  test "should get new" do
    get weather_data_new_url
    assert_response :success
  end

  test "should get create" do
    get weather_data_create_url
    assert_response :success
  end

  test "should get edit" do
    get weather_data_edit_url
    assert_response :success
  end

  test "should get update" do
    get weather_data_update_url
    assert_response :success
  end

  test "should get destroy" do
    get weather_data_destroy_url
    assert_response :success
  end
end

require "test_helper"

class DispersionEventsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dispersion_events_index_url
    assert_response :success
  end

  test "should get show" do
    get dispersion_events_show_url
    assert_response :success
  end

  test "should get new" do
    get dispersion_events_new_url
    assert_response :success
  end

  test "should get create" do
    get dispersion_events_create_url
    assert_response :success
  end

  test "should get edit" do
    get dispersion_events_edit_url
    assert_response :success
  end

  test "should get update" do
    get dispersion_events_update_url
    assert_response :success
  end

  test "should get destroy" do
    get dispersion_events_destroy_url
    assert_response :success
  end
end

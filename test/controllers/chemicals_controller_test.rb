require "test_helper"

class ChemicalsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get chemicals_index_url
    assert_response :success
  end

  test "should get show" do
    get chemicals_show_url
    assert_response :success
  end

  test "should get new" do
    get chemicals_new_url
    assert_response :success
  end

  test "should get create" do
    get chemicals_create_url
    assert_response :success
  end

  test "should get edit" do
    get chemicals_edit_url
    assert_response :success
  end

  test "should get update" do
    get chemicals_update_url
    assert_response :success
  end

  test "should get destroy" do
    get chemicals_destroy_url
    assert_response :success
  end
end

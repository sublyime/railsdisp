require "test_helper"

class ReceptorsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get receptors_index_url
    assert_response :success
  end

  test "should get show" do
    get receptors_show_url
    assert_response :success
  end

  test "should get new" do
    get receptors_new_url
    assert_response :success
  end

  test "should get create" do
    get receptors_create_url
    assert_response :success
  end

  test "should get edit" do
    get receptors_edit_url
    assert_response :success
  end

  test "should get update" do
    get receptors_update_url
    assert_response :success
  end

  test "should get destroy" do
    get receptors_destroy_url
    assert_response :success
  end
end

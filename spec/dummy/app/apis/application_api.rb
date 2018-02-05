class ApplicationApi < Cord::BaseApi
  abstract!

  default_scope(:abc) { |driver| driver.where('true') }
end

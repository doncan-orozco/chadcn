# frozen_string_literal: true

# The React export name (`InputOTP`), used by the parity harness and the catalog tree renderer. Application code uses
# {Chadcn::InputOtp}. It has its own file so Zeitwerk can autoload it (same shape as toaster.rb).
# @api private
Chadcn::InputOTP = Chadcn::InputOtp

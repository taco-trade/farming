import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MockTokenModule = buildModule("MockTokenModule", (m) => {
  const token = m.contract("MockToken");
  return { token };
});

export default MockTokenModule;

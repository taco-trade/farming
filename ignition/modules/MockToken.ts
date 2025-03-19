import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MockTokenModule = buildModule("MockTokenModule", (m) => {
  const token01 = m.contract("MockToken", [], {id: "TA"});
  m.call(token01, "initialize", [
    "testA",
    "TA",
    "18",
    "1000000000000000000",
  ]);
  const token02 = m.contract("MockToken", [], {id: "TB"});
  m.call(token02, "initialize", [
    "testB",
    "TB",
    "18",
    "1000000000000000000",
  ]);
  return { token01, token02 };
});

export default MockTokenModule;

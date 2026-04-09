// import consumer from "./consumer"
// consumer.subscriptions.create("NotificationsChannel", {
//   connected() {
//     console.log("Connected to NotificationsChannel!");
//   },
//   received(data) {
//     const alertHtml = `
//       <div class="alert alert-success alert-dismissible fade show fixed-top m-3" role="alert" style="z-index: 9999;">
//         <strong>${data.title}</strong>: ${data.body}
//         <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
//       </div>
//     `;
//     document.body.insertAdjacentHTML('afterbegin', alertHtml);
//   }
// });
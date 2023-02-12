import { useState, MouseEventHandler, ChangeEvent } from 'react';

import { getAuth, createUserWithEmailAndPassword } from 'firebase/auth';
import { app } from '@/components/firebase/initialize';

export default function SignUp() {
  const auth = getAuth(app);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (e: MouseEventHandler<HTMLButtonElement>) => {
    // signupに成功するとresが返ってくる、パスワードが違ったりした場合はerrorになるのでcacheする必要がある
    const res = await createUserWithEmailAndPassword(auth, email, password);
    console.log(res);
  };
  const handleChangeEmail = (e: ChangeEvent<HTMLInputElement>) => {
    setEmail(e.currentTarget.value);
  };
  const handleChangePassword = (e: ChangeEvent<HTMLInputElement>) => {
    setPassword(e.currentTarget.value);
  };

  return (
    <form className='mb-4 rounded bg-white px-8 pt-6 pb-8 shadow-md'>
      <div className='mb-4'>
        <label className='mb-2 block text-sm font-bold text-gray-700'>
          Username
        </label>
        <input
          className='focus:shadow-outline w-full appearance-none rounded border py-2 px-3 leading-tight text-gray-700 shadow focus:outline-none'
          id='username'
          type='text'
          placeholder='Username'
          onChange={handleChangeEmail}
        />
      </div>
      <div className='mb-6'>
        <label className='mb-2 block text-sm font-bold text-gray-700'>
          Password
        </label>
        <input
          className='focus:shadow-outline mb-3 w-full appearance-none rounded border border-red-500 py-2 px-3 leading-tight text-gray-700 shadow focus:outline-none'
          id='password'
          type='password'
          placeholder='******************'
          onChange={handleChangePassword}
        />
        <p className='text-xs italic text-red-500'>Please choose a password.</p>
      </div>
      <div className='flex items-center justify-between'>
        <button
          className='focus:shadow-outline rounded bg-blue-500 py-2 px-4 font-bold text-white hover:bg-blue-700 focus:outline-none'
          type='button'
          onClick={handleSubmit}
        >
          Sign Up
        </button>
      </div>
    </form>
  );
}
